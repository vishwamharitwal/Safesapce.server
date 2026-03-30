import os
import re

lib_dir = 'd:/flutter_app/SafeSpace/lib'

for root, _, files in os.walk(lib_dir):
    for str_file in files:
        if str_file.endswith('.dart'):
            filepath = os.path.join(root, str_file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()

            original = content
            
            while 'debugPrint(' in content:
                idx = content.find('debugPrint(')
                
                # Find start of line
                start_idx = idx
                while start_idx > 0 and content[start_idx-1] in ' \t':
                    start_idx -= 1
                if start_idx > 0 and content[start_idx-1] != '\n':
                    # Not start of line, just delete from 'debugPrint'
                    start_idx = idx
                
                # Parse balanced parentheses
                paren_start = idx + 10 # debugPrint( is 11 chars
                depth = 1
                curr_idx = paren_start + 1
                in_string = False
                str_char = None
                
                while curr_idx < len(content) and depth > 0:
                    char = content[curr_idx]
                    
                    if not in_string:
                        if char == '"' or char == "'":
                            in_string = True
                            str_char = char
                        elif char == '(':
                            depth += 1
                        elif char == ')':
                            depth -= 1
                    else:
                        if char == '\\':
                            curr_idx += 1 # skip escaped char
                        elif char == str_char:
                            in_string = False
                    
                    curr_idx += 1
                
                if depth == 0:
                    end_idx = curr_idx
                    # Find trailing semicolon
                    while end_idx < len(content) and content[end_idx] in ' \t\r\n':
                        if content[end_idx] == ';':
                            break
                        end_idx += 1
                    
                    if end_idx < len(content) and content[end_idx] == ';':
                        end_idx += 1
                        # Remove trailing spaces and newline
                        while end_idx < len(content) and content[end_idx] in ' \t\r':
                            end_idx += 1
                        if end_idx < len(content) and content[end_idx] == '\n':
                            end_idx += 1
                        
                        content = content[:start_idx] + content[end_idx:]
                    else:
                        # Fallback if no semicolon found
                        content = content[:start_idx] + '/* debugPrint removed */' + content[curr_idx:]
                else:
                    # Malformed file or our parser failed?
                    break
            
            if content != original:
                print(f'Updated {filepath}')
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(content)
