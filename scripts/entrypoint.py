import os
import re
import subprocess
import sys

dnsmasq_dir = "/etc/dnsmasq.d"
blocklist_data_dir = "/usr/local/share/dnsmasq"

blocklist_config_files = [f"{dnsmasq_dir}/blocklist.conf"]
blocklist_urls_files = [f"{blocklist_data_dir}/blocklist-urls.txt",f"{blocklist_data_dir}/blocklist-urls.local.txt"]
blocklist_conf = f"{dnsmasq_dir}/blocklist.conf"

def process_blocklist_urls_files(urls_files):
  blocklist_urls = []
  for urls_file in urls_files:
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
  return blocklist_urls

def download_blocklists(urls):
  count = 0
  for url in urls:
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

def remove_file_if_exists(file_path):
  if os.path.exists(file_path):
    print(f"Removing existing {file_path}..")
    os.remove(file_path)

def start_process(command):
  try:
    print(f"Starting process: {command}")
    os.execvp(command[0], command)
  except Exception as e:
    print(f"Error starting process {command}: {e}")

def update_dnsmasq_config():
  try:
    with open("/etc/dnsmasq.conf", "r+") as dnsmasq_conf:
      content = dnsmasq_conf.read()
      if not content.find("port=") >= 0:
        dnsmasq_conf.write(f"\nport={os.getenv('DNS_LISTEN_PORT', 53)}\n")
      else:
        print("DNS listen port already configured in /etc/dnsmasq.conf. Skipping port configuration.")
      if not content.find("cache-size=") >= 0:
        dnsmasq_conf.write(f"cache-size={os.getenv('DNS_CACHE_SIZE', 10000)}\n")
      else:
        print("DNS cache size already configured in /etc/dnsmasq.conf. Skipping cache size configuration.")
      print("Updated /etc/dnsmasq.conf with runtime configuration.")
  except Exception as e:
    print(f"Error updating /etc/dnsmasq.conf: {e}")

remove_file_if_exists(blocklist_conf)

download_blocklists(
  process_blocklist_urls_files(blocklist_urls_files)
)

update_dnsmasq_config()

start_process(["dnsmasq", "--conf-file=/etc/dnsmasq.conf"])