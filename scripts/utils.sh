# Source environment variables from a file if it exists
function source_env_file() {
  local env_file="$1"
  if [ -f "$env_file" ]; then
    echo "Loading environment variables from $env_file..."
    set -a
    source "$env_file"
    set +a
  else
    echo "Warning: $env_file not found. Skipping."
  fi
}

# Print the values of specified environment variables
function print_env_vars() {
  local vars=("$@")
  echo "Using the following configuration:"
  for var in "${vars[@]}"; do
    echo "  $var: ${!var}"
  done
}

# Check if specified local files exist and print a warning if they don't
function check_local_files() {
  local files=("$@")
  for file in "${files[@]}"; do
    if [ ! -f "$file" ]; then
      echo "Warning: $file not found. Creating it now."
      touch "$file"
    fi
  done
}