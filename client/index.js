const core = require('@actions/core');
const github = require('@actions/github');
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


async function make_api_request(action, postObj) {

  const https = require('https');

  api_uri = new URL(garo_url);

  var data = "";

  current_time = Math.floor(new Date().getTime() / 1000).toString();

  if (true) {
    postObj.dryrun = true;
  }

  if (action == "start") {
    console.log("Sending start action to API");
  } else if (action == "state") {
    if (! "name" in postObj) {
      throw "name missing";
    }
    console.log("Sending state action to API");
  } else{
    return False;
  }

  data = JSON.stringify(postObj);

  signature = crypto.createHmac('sha512', github_token).update(data).digest('hex');

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
      if (d != "error") {
        return JSON.parse(d)
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


function sleep(ms) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}


try {
  const wait_for_start = getItem('WAIT_FOR_START', "true");
  const action = getItem('ACTION', "start");
  const garo_url = getItem('GARO_URL');

  postObj = {
    github_token: getItem('GITHUB_TOKEN'),
    repo: getItem('REPO'),
    github_commit: getItem('GITHUB_COMMIT'),
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


  result = {"name": "", "runnerstate": "failure"}

  if (action == "start") {
    result =  make_api_request("start", postObj);

    if (result["runnerstate"] == "starting" && wait_for_start) {
      while (i < 10) {
        i++;
         sleep(20000);
        state_result =  make_api_request("state", postObj);
        if ("runnerstate" == "started") {
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
