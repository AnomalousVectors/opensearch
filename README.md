# OpenSearch

> ⚠️ In early development. Expect breaking changes and partial functionality.

This repo provides a custom OpenSearch and Dashboards instances to support agentic penetration testing 

## Quick Start

### Install prereqs

#### Docker

Ubuntu/Debian:

- Docs: [https://docs.docker.com/engine/install/ubuntu/](https://docs.docker.com/engine/install/ubuntu/)
- Note testing is done using the Official packages below, not Ubuntu/Debian releases.

```shell
# Remove distro-provided Docker packages if present (safe if not installed)
sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
sudo apt-get autoremove -y

# Prereqs
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

# Add Docker’s official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker’s official apt repo
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine + Compose v2 plugin
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Verify
sudo docker --version
sudo docker compose version
```

Linux: [https://docs.docker.com/desktop/setup/install/linux/](https://docs.docker.com/desktop/setup/install/linux/)

Windows: [https://docs.docker.com/desktop/setup/install/windows-install/](https://docs.docker.com/desktop/setup/install/windows-install/)

#### Make

Nix

```shell
# Ubuntu/Debian
sudo apt update
sudo apt install make

# Fedora/RHEL
sudo dnf install make

# Arch Linux
sudo pacman -S make

# macOS
xcode-select --install make
```

Windows

[https://chocolatey.org/install](https://chocolatey.org/install)

Install choco via admin PowerShell

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

[https://community.chocolatey.org/packages/make](https://community.chocolatey.org/packages/make)

```powershell
choco install make
```



### Clone the repo

```shell
git clone https://github.com/AnomalousVectors/opensearch.git
cd opensearch
```



### Review environment config

- View and edit the .env file.
- Ensure to update `DATA_VOLUME_ROOT`. This is where persistent data and logs will be stored. Keep the path outside of this repo's root.
- Adjust `OPENSEARCH_JAVA_OPTS` to manage heap size. Ensure it matches your desired range by adjusting the `Xms` and `Xmx` values.
- The remaining defaults should be fine in most cases.



### Start the Docker stack

Use the following to start the Docker stack. It launches `./scripts/start.sh` which will initiate the following:

1. If first run:
  - Prompt user to create a new OpenSearch Admin password.
  - Download Docker images.
  - Generate self-signed TLS certificates.
2. Launch of two Docker containers, OpenSearch and OpenSearch Dashboards.
3. Instance monitoring and healthchecks when ready.

```shell
cd opensearch
make
sudo make docker-up
```

The following shows a truncated example of a healthy initial launch.

```
$ make docker-up
./scripts/start.sh
First run detected. Enter initial OpenSearch admin password (save this for future runs):
*****
Repeat initial OpenSearch admin password:
*****
OpenSearch stores only the hash. Dashboards authenticates to OpenSearch using this credential.
Change password docs: https://opensearch.org/docs/latest/security/access-control/users-passwords/#change-passwords
#1 [internal] load local bake definitions
#1 reading from stdin 683B done
#1 DONE 0.0s
...
#13 resolving provenance for metadata file
#13 DONE 0.0s
[+] Running 3/3
 ✔ anomalousvectors-opensearch:3.6.0   Built                       0.0s
 ✔ Network opensearch_opensearch-net   Created                     0.0s
 ✔ Container opensearch                Healthy                     21.9s
Waiting for OpenSearch to become reachable...
#1 [internal] load local bake definitions
#1 reading from stdin 1.34kB done
#1 DONE 0.0s
...
#23 [opensearch-dashboards] resolving provenance for metadata file
#23 DONE 0.0s
[+] Running 4/4
 ✔ anomalousvectors-opensearch:3.6.0               Built           0.0s
 ✔ anomalousvectors-opensearch-dashboards:3.6.0    Built           0.0s
 ✔ Container opensearch                            Healthy         18.8s
 ✔ Container opensearch-dashboards                 Healthy         28.0s
```



### Validate

After healthchecks complete and return `Healthy` statuses, use the following to manually confirm that you can access both containers.

Optionally, confirm Opensearch API access and health:

```shell
# Update password and opensearch.url in the example commands below
curl -sk -u "admin:admin" "https://opensearch.url:9200/_cluster/health?pretty"
curl -sk -u "admin:admin" "https://opensearch.url:9200/_cat/indices?v"
```

Optionally, confirm Opensearch Dashboards API access and health:

```shell
# Update password and opensearch-dashboards.url in the commands below
curl -sk -u admin:admin -H "osd-xsrf: true" https://opensearch-dashboards.url:5601/api/status
curl -sk -u admin:admin -H "osd-xsrf: true" https://opensearch-dashboards.url:5601/api/stats
```

Login to Dashboards at [https://opensearch-dashboards.url:5601/app/login](https://opensearch-dashboards.url:5601/app/login). Use 'admin' as the username and the password you set upon initial launch.

### Use

At this point, it will be ready to use. For example, you can configure the [Burp Exporter](https://github.com/AnomalousVectors/burp-exporter) Burp Suite extension to export Burp data for processing. Just add [https://opensearch.url:9200](https://opensearch.url:9200) as a Destination within Burp Exporter.

After indexes are created and populated in OpenSearch, you can leverage [Dashboards'](https://docs.opensearch.org/latest/dashboards/) many features. The [Discover](https://docs.opensearch.org/latest/dashboards/discover/index-discover/) application is a great place to start exploring because it will enable you to run Lucene and DQL queries against the indexes.

Before using Discover, you just need to map the index names to Index Patterns within Dashboards. The easiest way to do this is via the API. Note, If you create the Index Patterns before the indexes are created in OpenSearch, you will see an error when attempting to view the index data within the Dashboards' Discover application. Thus, it may be best to populate the indexes before creating these Index Patterns. Use the following to create Index Patterns that align with Burp Exporter's default index names:

```shell
# Create five Index Patterns
curl -sk -u admin:admin -X POST "https://opensearch-dashboards.url:5601/api/saved_objects/index-pattern/tool-burp-exporter" -H "osd-xsrf: true" -H "Content-Type: application/json" -d "{\"attributes\":{\"title\":\"tool-burp-exporter\",\"timeFieldName\":\"meta.indexed_at\"}}"

curl -sk -u admin:admin -X POST "https://opensearch-dashboards.url:5601/api/saved_objects/index-pattern/tool-burp-findings" -H "osd-xsrf: true" -H "Content-Type: application/json" -d "{\"attributes\":{\"title\":\"tool-burp-findings\",\"timeFieldName\":\"meta.indexed_at\"}}"

curl -sk -u admin:admin -X POST "https://opensearch-dashboards.url:5601/api/saved_objects/index-pattern/tool-burp-settings" -H "osd-xsrf: true" -H "Content-Type: application/json" -d "{\"attributes\":{\"title\":\"tool-burp-settings\",\"timeFieldName\":\"meta.indexed_at\"}}"

curl -sk -u admin:admin -X POST "https://opensearch-dashboards.url:5601/api/saved_objects/index-pattern/tool-burp-sitemap" -H "osd-xsrf: true" -H "Content-Type: application/json" -d "{\"attributes\":{\"title\":\"tool-burp-sitemap\",\"timeFieldName\":\"meta.indexed_at\"}}"

curl -sk -u admin:admin -X POST "https://opensearch-dashboards.url:5601/api/saved_objects/index-pattern/tool-burp-traffic" -H "osd-xsrf: true" -H "Content-Type: application/json" -d "{\"attributes\":{\"title\":\"tool-burp-traffic\",\"timeFieldName\":\"meta.indexed_at\"}}"

# Confirm
curl -sk -u admin:admin -H "osd-xsrf: true" "https://opensearch-dashboards.url:5601/api/saved_objects/_find?type=index-pattern&per_page=100"
```

Navigate to Dashboards' Discover application, [https://opensearch-dashboards.url:5601/app/data-explorer/discover](https://opensearch-dashboards.url:5601/app/data-explorer/discover). The Index Patterns will be available in a dropdown on the top of the sidebar. From there, you can select the index you want to run Lucene or DQL queries against.

## Ideas and Feedback

We welcome ideas, feedback, and pull requests. Feel free to open a discussion, issue, or submit a PR.

## License

This project is licensed under the [MIT License](LICENSE).