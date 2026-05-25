import os
import re
import subprocess
import sys

dnsmasq_dir = "/etc/dnsmasq.d"
blocklist_data_dir = "/usr/local/share/dnsmasq"

blocklist_config_files = [f"{dnsmasq_dir}/blocklist.conf"]
blocklist_urls_file = [f"{blocklist_data_dir}/blocklist-urls.txt",f"{blocklist_data_dir}/blocklist-urls.local.txt"]
blocklist_urls = []
blocklist_conf = f"{dnsmasq_dir}/blocklist.conf"

env_vars = ["DNS_BIND_IP", "DNS_CACHE_SIZE", "DNS_LISTEN_PORT"]
print("Using the following environment variables:")
for var in env_vars:
  if os.getenv(var) is None:
    print(f"Warning: Environment variable {var} is not set. Using default value.")
  print(f"  - {var}: {os.getenv(var)}")

for urls_file in blocklist_urls_file:
  if not os.path.exists(urls_file):
    print(f"Blocklist config file {urls_file} not found. Skipping.")
    continue
  try:
    with open(urls_file, "r") as f:
      print(f"Reading blocklist config from {urls_file}...")
      for line in f:
        # Remove leading and trailing whitespaces
        line = line.strip()
        if line and not line.startswith("#"): # Skip empty lines and comments
          blocklist_urls.append(line)
  except FileNotFoundError:
    print(f"Blocklist config file {urls_file} not found. Skipping.")

# If no blocklist URLs were found, exit with an error message.
if (len(blocklist_urls) == 0):
  print("No blocklist URLs found. Exiting.")
  sys.exit(1)
print(f"Found {len(blocklist_urls)} blocklist URLs.")

if os.path.exists(blocklist_conf):
  print(f"Removing existing {blocklist_conf}..")
  os.remove(blocklist_conf)

count = 0

for url in blocklist_urls:
  print(f"Processing blocklist URL: {url}")
  try:
    # Use curl to fetch the blocklist content 
    result = subprocess.run(["curl", "-sL", url], capture_output=True, text=True)
    if result.returncode != 0:
      print(f"Failed to fetch blocklist from {url}: {result.stderr}")
      continue

    # Append the fetched content to the blocklist file
    with open(blocklist_conf, "a") as blocklist_file:
      for line in result.stdout.splitlines():
        line = line.strip()
        parts = line.split(" ")
        if line and not line.startswith("#") and parts[0] != "fe80::1%lo0": # Skip empty lines and comments
          blocklist_file.write(f"address=/{parts[1]}/{parts[0]}\n")
          count += 1
          if parts[0] == "0.0.0.0":
            blocklist_file.write(f"address=/{parts[1]}/::\n")
      print(f"Appended blocklist from {url} to {blocklist_conf}")
  except Exception as e:
    print(f"Error processing blocklist URL {url}: {e}")

print(f"Total block rules generated: {count:,}")

try:
  print("Starting dnsmasq with the generated blocklist...")
  os.execvp("dnsmasq", ["dnsmasq", "--conf-file=/etc/dnsmasq.conf"])
except Exception as e:
  print(f"Error starting dnsmasq: {e}")

