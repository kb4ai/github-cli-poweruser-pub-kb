
import json
import csv
import argparse
import sys

# Argument parsing
parser = argparse.ArgumentParser(description='Convert JSON to CSV.')
parser.add_argument('field_name', nargs='?', default='Status', help='Field name to extract from JSON.')

args = parser.parse_args()

# Read JSON from standard input
input_data_str = sys.stdin.read()
input_data = json.loads(input_data_str)

# Initialize CSV writer to write to standard output
csv_writer = csv.writer(sys.stdout)

# Write header
csv_writer.writerow(["Text of field Title", f"Text of {args.field_name}", f"Id of {args.field_name}", "Id of Text field", "ITEM_ID"])

# Extract required fields
for node in input_data['data']['node']['items']['nodes']:
    title_text = node['content']['title']
    title_id = None
    field_name_text = None
    field_name_id = None
    item_id = node['id']
    
    for field_value in node['fieldValues']['nodes']:
        field_name = field_value.get('field', {}).get('name')
        
        if field_name == "Title":
            title_id = field_value['field']['id']
        elif field_name == args.field_name:
            field_name_text = field_value.get('name')
            field_name_id = field_value['field']['id']
    
    csv_writer.writerow([title_text, field_name_text, field_name_id, title_id, item_id]) 
