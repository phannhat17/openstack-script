# Function to append a key-value pair to a section in a config file if it doesn't already exist
append_if_missing() {
    local file="$1"
    local section="$2"
    local key="$3"
    local value="$4"
    
    # Ensure section exists
    if ! grep -q "^\[$section\]" "$file"; then
        echo -e "\n[$section]" | sudo tee -a "$file" > /dev/null
    fi

    # Check if key exists within the section
    if ! grep -q "^$key" "$file" | sed -n "/^\[$section\]/, /^\[.*\]/p" "$file"; then
        # Append the key-value pair if missing
        echo "$key = $value" | sudo tee -a "$file" > /dev/null
    fi
}
