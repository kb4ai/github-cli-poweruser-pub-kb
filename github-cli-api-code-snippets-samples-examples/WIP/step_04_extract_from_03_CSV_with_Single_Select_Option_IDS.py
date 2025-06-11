
import json
import csv
import sys

# Read JSON from standard input
input_data_str = sys.stdin.read()
input_data = json.loads(input_data_str)

# Initialize CSV writer to write to standard output
csv_writer = csv.writer(sys.stdout)

# Write header
csv_writer.writerow(["Field Name", "Text of Single Select Option", "OPTION_ID", "FIELD_ID"])

# Extract required fields
for field_node in input_data['data']['node']['fields']['nodes']:
    field_name = field_node.get('name')
    field_id = field_node.get('id')  # Extracting Field ID
    if field_name and 'options' in field_node:
        for option in field_node['options']:
            option_name = option.get('name')
            option_id = option.get('id')
            csv_writer.writerow([field_name, option_name, option_id, field_id]) 
