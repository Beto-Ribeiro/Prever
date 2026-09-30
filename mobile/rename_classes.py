import os
import glob

replacements = [
    ('sLogCad', 'SLogCad'), 
    ('_sLogCad_State', '_SLogCadState'), 
    ('confEmail', 'ConfEmail'), 
    ('_confEmailState', '_ConfEmailState'), 
    ('changePassword', 'ChangePassword'), 
    ('_changePasswordState', '_ChangePasswordState'), 
    ('writeChangedPassword', 'WriteChangedPassword'), 
    ('_writeChangedPasswordState', '_WriteChangedPasswordState'), 
    ('sLogin', 'SLogin'), 
    ('_sLogin_State', '_SLoginState')
]

for f in glob.glob('lib/**/*.dart', recursive=True):
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
    
    for old, new in replacements:
        content = content.replace(old, new)
        
    with open(f, 'w', encoding='utf-8') as file:
        file.write(content)
print("Renaming complete.")
