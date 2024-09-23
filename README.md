
# Heroku Buildpack for Middleware

![Heroku](https://img.shields.io/badge/Heroku-430098?style=for-the-badge&logo=heroku&logoColor=white)
![Middleware](https://img.shields.io/badge/Middleware-5B5FC7?style=for-the-badge&logo=middleware&logoColor=white)
![License](https://img.shields.io/github/license/middleware-labs/heroku-buildpack-middleware?style=for-the-badge)

The Heroku buildpack for Middleware is a [buildpack](https://devcenter.heroku.com/articles/buildpacks) for the
[Middleware Agent (mw-agent)](https://github.com/middleware-labs/mw-agent). The buildpack to
installs and runs the mw-agent on a Dyno to receive,
process and export metric and trace data to [Middleware Observability platform](https://middleware.io).

To collect custom application metrics or traces, include the language appropriate [Middleware APM package](https://docs.middleware.io/apm-configuration/apm_overview) in your application.

## Table of Contents

- [Installation](#installation)
- [Buildpack Ordering](#buildpack-ordering)
- [Buildpack and `mw-agent` Version](#buildpack-and-mw-agent-version)
- [Configuration](#configuration)
- [Dyno Hostnames](#dyno-hostnames)
- [Preexec Script](#preexec-script)
- [Metrics](#metrics)
- [Traces](#traces)
- [Logs](#logs)
- [Troubleshooting](#troubleshooting)

## Installation

Install the [Heroku CLI](https://devcenter.heroku.com/articles/heroku-cli), login, and create an
app. 

1. Set your Heroku application name to APPNAME environment variable.
```
export APPNAME=<YOUR_HEROKU_APPLICATION_NAME>
```

2. Copy your Middleware API key and target by visiting Middleware installation page and export it to an environment variable

```
export MW_API_KEY=<YOUR_MW_API_KEY>
export MW_TARGET=<YOUR_MW_TARGET>
```

3. Add the Middleware buildpack to your Heroku project:

```
cd <HEROKU_APPLICATION_DIRECTORY>

# Configure Heroku to expose Dyno metadata inside the app.
heroku labs:enable runtime-dyno-metadata -a $APPNAME

# Set required environment variables
heroku config:add MW_API_KEY=$MW_API_KEY
heroku config:add MW_TARGET=$MW_TARGET

# Set hostname in Middleware as appname.dynotype.dynonumber for metrics continuity across dyno ID changes.
heroku config:add MW_DYNO_HOSTNAME=true

# Add buildpack for mw-agent
heroku buildpacks:add --index 1 https://github.com/middleware-labs/heroku-buildpack-middleware.git

# Create an emptycommit and deploy your app 
git commit --allow-empty -m "empty commit"
git push heroku main

# Check logs
heroku logs -a <app-name> --tail
```

`mw-agent` is installed by default at `/app/mw-agent` directory and is automatically started on every dyno start. 

`mw-agent` provides local OpenTelemetry endpoints on port 9313 for gRPC and 9320 for HTTP. It also provides a local fluentforward endpoint on port 8006.

## Buildpack Ordering

Typically, your application buildpack should be the last buildpack in the `heroku buildpacks` command output. Heroku uses the last buildpack in the list to determine the process type for the application. Having Middleware buildpack as the last buildpack would override the process type preventing your application to run correctly.

**Note**: Your application buildpack should always be after Middleware buildpack.

In addition, any buildpacks that override `/app` directory should be before Middleware buildpack in order. For example, if your application requires a Node, Middleware and `apt` buildpacks, the output of `heroku buildpacks` should be as follows

```
1. https://github.com/heroku/heroku-buildpack-apt.git
2. https://github.com/middleware-labs/heroku-buildpack-middleware.git
3. heroku/nodejs
```

## Buildpack and `mw-agent` Version

Heroku recommends to always use the latest commit of a buildpack. 

However, if you wish to use a specific tag of the buildpack instead of the latest git commit, use the command below. 

```
heroku buildpacks:add https://github.com/middleware-labs/heroku-buildpack-middleware.git#<TAG_NAME>
```
Use the appropriate value for `<TAG_NAME>` from [here](https://github.com/middleware-labs/heroku-buildpack-middleware/tags).

By default, the buildpack pins the latest version of the [Middleware Agent](https://github.com/middleware-labs/mw-agent) at the time of release. You can pin the Agent to an earlier version by setting the `MW_AGENT_VERSION` environment variable.

```
heroku config:add MW_AGENT_VERSION=1.7.7
```

You will have to rebuild your application slug when you change the buildpack release and/or change the `mw-agent` verison. 

```
cd <HEROKU_APPLICATION_DIRECTORY>

# Rebuild your slug with the new Agent version:
git commit --allow-empty -m "Rebuild slug"
git push heroku main
```

## Configuration

Below is the list of all environment variables that you can set in your Heroku application to change the behavior of the Middleware buildpack and `mw-agent`.

### Environment Variabls for the buildpack


| Setting                            | Required | Description |
|------------------------------------|----------|-----------------------------------------------------------------|
| `MW_DYNO_DISABLE_AGENT`            | No       | This will disable `mw-agent` in the Dyno. Default is `false`. |
| `MW_DYNO_HOSTNAME`                 | No       |  Set to `true` to use the dyno name, such as `appname.web.1` as the hostname. See the [hostname section](#hostname) below for more information. Defaults to `false`. |
| `MW_DYNO_PREEXEC_SCRIPT`           | No       | The absolute location of the bash script to be executed before starting `mw-agent`. |
| `MW_API_KEY`                       | Yes      | Your Middleware API key for your account. |
| `MW_TARGET`                        | Yes      | Middleware target for your account. |
| `MW_AGENT_VERSION`                 | No       | `mw-agent` release to install in the buildpack |
| `MW_HOST_TAGS`                     | No       | Tags for this host. Tags are comma separated key-value pairs. E.g. MW_HOST_TAGS=key1:value1,key2:value2. |
| `MW_FLUENT_PORT`                   | No       | Port for the Fluent receiver. Defaults to `8006`. |
| `MW_LOGFILE`                       | No       | Path to the log file for `mw-agent` logs. Defaults log path is /var/log/mw-agent.log. |
| `MW_LOGFILE_SIZE`                  | No       | Log file size for `mw-agent` logs. This flag only applies if the `logfile` flag is specified. Defaults to `1` MB. |
| `MW_AGENT_FEATURES_METRIC_COLLECTION`| No      | Enable or disable metric collection (alias for infrastructure monitoring). Defaults to `true`. |
| `MW_AGENT_FEATURES_LOG_COLLECTION` | No       | Enable or disable log collection. Defaults to `true`. |
| `MW_AGENT_SELF_PROFILING`          | No       | Enable or disable profiling of the Middleware agent itself. Defaults to `false`. |
| `MW_AGENT_INTERNAL_METRICS_PORT`   | No       | Port where the Middleware agent will expose Prometheus metrics. Defaults to `8888`. |

## Dyno Hostnames

`mw-agent` installed through the buildpack detects the hostname of the Dyno it is running on using operating system APIs. By default, Dyno ID used as a hostname by the operating system. 

Dynos can move to different host machines when there is a new deployment, configuration changes or resource needs/availability change. This causes Dyno ID to change resulting a new host being reported to Middleware. This makes it harder to monitor Dyno metrics and performance.

When `MW_DYNO_HOSTNAME` is set to `true` in the buildpack configuration, `mw-agent` reports the hostname in appname.dyno format (e.g. `myapp.web.1`, `myapp.run.2`). This allows for continuity in Dyno metric monitring giving accurate picture of your Heroku application performance.

**Note**: You may see metric continuity errors since Middleware will not receive any metrics from Dyno while it is cycled.

For `MW_DYNO_HOSTNAME` to work, [Dyno metadata](https://devcenter.heroku.com/articles/dyno-metadata) needs to be enabled in Heroku application configuration. 

Dyno metadata can be enabled using command below

```
heroku labs:enable runtime-dyno-metadata -a <app name>
```

Heroku buildpack for Middleware relies on `HEROKU_APP_NAME` environment variable obtained through Dyno metadata to update Dyno hostname.

## Preexec Script

The buildback behavior can be customized by including a preexec script which runs just before the `mw-agent` is started.  The preexec script can be passed to the buildpack using `MW_DYNO_PREEXEC_SCRIPT` environment variable. 

Below is an example of how you can set `MW_DYNO_PREEXEC_SCRIPT`.

```
heroku config:add MW_DYNO_PREEXEC_SCRIPT=/app/preexec.sh
```

You will have to provide preexec script along with your application. 

The preexec script can be used to modify the configuration variables mentioned [above](#configuration) and enable Middleware [integrations](https://docs.middleware.io/integrations/integrations_overview). 

One common use case for the preexec script is to disable `mw-agent` for selected Dyno process types (e.g. `run`) and to provision integration configuration if any.

Below is an example of a preexec script that will disable `mw-agent` for `run` process type and provide MySQL configuration to enable Middleware [MySQL integration](https://docs.middleware.io/integrations/mysql-integration).

```
#!/bin/bash

# Extract the process type from the DYNO environment variable
DYNO_PROC_TYPE="${DYNO%%.*}"

# Check if the process type is 'run' and set MW_DYNO_DISABLE_AGENT to true if it is
if [ "$DYNO_PROC_TYPE" == "run" ]; then
  export MW_DYNO_DISABLE_AGENT=true
else
  # Create MySQL credentials file so that mw-agent can collect metrics
  cat <<EOF > /app/mysql-creds.yaml
mysql:
    endpoint: localhost:3306
    username: $MYSQL_USER
    password: $MYSQL_PASSWORD
EOF
fi

```

## Metrics

By default, the buildpack collects system metrics for the host machine running your Dyno.  To disable host system metrics collection, set the `MW_AGENT_FEATURES_METRIC_COLLECTION` environment variable to `false` in your Heroku application configuration.

**Note**: System metrics are not available for individual Dynos by enabling [log-runtime-metrics](https://devcenter.heroku.com/articles/log-runtime-metrics) is not supported.

## Traces

Applications running on Dyno can use language specific [Middleware APM packages](https://docs.middleware.io/apm-configuration/apm_overview) to submit traces to Middleware platform. Middleware APM packages seamlessly integrate with the buildpack and allow submission of custom metrics in addition to application traces and spans.

## Logs

Logs for applications running on Heroku Dynos can be collected using [Middleware's Heroku Log Drains]() integration.

## Troubleshooting

### How do I know if `mw-agent` is running in the background ?

If you are not seeing data in your Middleware account after installing the buildpack, you can check `mw-agent` log files by connecting to your Dyno.

First ensure that `mw-agent` is running inside the Dyno.

```
heroku ps:exec -a <your-app-name>

# Establishing credentials... done
# Connecting to web.1 on ⬢ go-heroku-middleware

~ $ ps aux | grep mw-agent
u14900         4  1.3  0.1 1362616 87804 ?       Sl   23:54   0:00 /app/mw-agent/opt/mw-agent/bin/mw-agent start --otel-config-file=/app/mw-agent/etc/mw-agent/otel-config.yaml
```

You can also check for any error messages in the `mw-agent` log file.

```
~ $ cat /app/mw-agent/mw-agent.log
{"level":"INFO","time":"2024-09-20T23:54:21.682Z","caller":"host-agent/main.go:308","message":"starting host agent","agent location":"/app/mw-agent/opt/mw-agent/bin/mw-agent","hostname":"396f01fe-e4b7-4b94-99e4-89aa79706e74"}
```
