## Development and Deployment

### Client Development

To test and build the `dist` (see reference in [action.yml]), run:  
`npm run all`

### API Development

The API runs on Lambda and uses Python 3.8

- `black` is used for linting
- `doctest` is used for some testing
- `venv` is used for the virtual environment

The first time, run `make test-python-full` to install `venv`, dependencies and
test the python code.

Subsequent runs can use `make test-python` to skip installing dependencies.

There is a _dev_ workspace and API that can be used, see deployment below.

### API Deployment

The API uses Terraform, the code for that is in [garo_terraform].

Terraform uses 0.14.7 (specified in the [.terraform-version] file).

In [garo_terraform] run `tfenv install` and `tfenv use` to automatically pick up
the version file and install the right version.

[Terraform workspaces] is used for `dev`, `staging` and `prod` environments.

To deploy dev, do the follow:
1. in GARO root, run `make build-full` to build the Lambda ZIP
1. assume the `co-github-action-runner-admin` role:
  - `eval $(gds aws co-github-action-runner-admin -e)`
1. in [garo_terraform] run:
  - `terraform init`
  - `terraform workspace select dev`
  - `terraform apply`

Deployment of staging and production is done by this workflow:
[../.github/workflows/deploy.yml](../.github/workflows/deploy.yml)  
Which does the following:
1. Gets an `ondemand` runner using the current production API
1. Builds and deploys the main branch to staging
1. Gets a `spot` runner using the new staging API
1. Tests the staging runner
1. Deploys to production using the same runner from step 1.
1. Gets a `spot` runner using the new production API
1. Tests the new production runner


[action.yml]: ../client/action.yml#L67
[Terraform workspaces]: https://www.terraform.io/docs/cloud/workspaces/index.html
[garo_terraform]: ../garo_terraform/
[.terraform-version]: ../garo_terraform/.terraform-version
