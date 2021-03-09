const core = require('@actions/core');
const wait = require('./wait');
const crypto = require('crypto')


const getItem = (itemName, defaultStr = null) => {
  const res = core.getInput(itemName);
  if (res.length == 0) {
    if (defaultStr == null) {
      throw `${itemName} not set`;
    }
    return defaultStr;
  }
  return res;
}


async function make_api_request(action, garo_url, github_token, github_commit, postObj) {

  const https = require('https');

  const api_uri = new URL(garo_url);

  const current_time = Math.floor(new Date().getTime() / 1000).toString();
  postObj.time = current_time;

  postObj.dryrun = true;

  if (action == "start")
  {
    console.log("Sending start action to API");
  }
  else if (action == "state")
  {
    if ("name" in postObj) {
      console.log("Sending state action to API");
    } else {
      throw "name missing";
    }
  }
  else
  {
    return false;
  }

  const data = JSON.stringify(postObj);

  const signature = crypto.createHmac('sha512', github_token).update(data).digest('hex');

  const options = {
    hostname: api_uri.hostname,
    port: 443,
    path: `/${action}`,
    method: 'POST',
    headers: {
      'X-GitHub-Token': github_token,
      'X-GitHub-Signature': signature,
      'X-GitHub-CommitSHA': github_commit,
      'Content-Type': 'application/json',
      'Content-Length': data.length
    }
  }

  const req = https.request(options, res => {
    console.log(`statusCode: ${res.statusCode}`)

    res.on('data', d => {
      console.log("Data response:");
      const data_resp = d.toString()
      console.log(data_resp);
      if (data_resp != "error") {
        return JSON.parse(data_resp)
      }
      throw "bad response";
    })
  })

  req.on('error', error => {
    throw error;
  })

  req.write(data)
  req.end()
}


async function run() {
  try {
    const wait_for_start = getItem('WAIT_FOR_START', "true");
    const action = getItem('ACTION', "start");
    const garo_url = getItem('GARO_URL');
    const github_token = getItem('GITHUB_TOKEN');
    const github_commit = getItem('GITHUB_COMMIT');

    let postObj = {
      repo: getItem('REPO'),
      account_id: getItem('RUNNER_ACID'),
      external_id: getItem('RUNNER_EXID'),
      type: getItem('RUNNER_TYPE', "spot"),
      region: getItem('RUNNER_REGION', "eu-west-2"),
      timeout: getItem('RUNNER_TIMEOUT', "3600"),
    }

    const rName = getItem('RUNNER_NAME', "");
    if (rName != "") {
      postObj["name"] = rName
    }

    const rSub = getItem('RUNNER_SUBNET', "");
    if (rSub != "") {
      postObj["subnet"] = rSub
    }

    const rSg = getItem('RUNNER_SG', "");
    if (rSg != "") {
      postObj["sg"] = rSg
    }


    let result = {"name": "", "runnerstate": "failure"}

    if (action == "start") {
      result = await make_api_request(
        "start",
        garo_url,
        github_token,
        github_commit,
        postObj
      );

      if (result["runnerstate"] == "starting" && wait_for_start) {
        let i = 0;
        while (i < 10) {
          i++;
          await wait(20000);

          const state_result = await make_api_request(
            "state",
            garo_url,
            github_token,
            github_commit,
            postObj
          );

          if (state_result["runnerstate"] == "started") {
            result = state_result;
            break;
          }
        }
      }
    }

    core.setOutput("name", result.name);
    core.setOutput("runnerstate", result.runnerstate);

  } catch (error) {
    if (typeof(error) == "object" && "message" in error)
    {
      core.setFailed(error.message);
    }
    else
    {
      core.setFailed(error);
    }
  }
}

run();
