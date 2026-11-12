"""Environment-based Snowflake authentication; secrets are never printed."""
import os
import re


def identifier(value: str) -> str:
    if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', value):
        raise ValueError('SQL identifiers must contain only letters, digits and underscores')
    return value.upper()


def connect(*, database=True):
    import snowflake.connector
    required = ['SNOWFLAKE_ACCOUNT', 'SNOWFLAKE_USER', 'SNOWFLAKE_ROLE']
    missing = [name for name in required if not os.environ.get(name)]
    if missing:
        raise ValueError('Configure these environment variables first: ' + ', '.join(missing))
    params = {'account': os.environ['SNOWFLAKE_ACCOUNT'],
              'user': os.environ['SNOWFLAKE_USER'],
              'role': os.environ['SNOWFLAKE_ROLE'],
              'login_timeout': 120,
              'session_parameters': {'QUERY_TAG': 'elio_assessment'}}
    if os.environ.get('SNOWFLAKE_PRIVATE_KEY_PATH'):
        params['private_key_file'] = os.environ['SNOWFLAKE_PRIVATE_KEY_PATH']
        if os.environ.get('SNOWFLAKE_PRIVATE_KEY_PASSPHRASE'):
            params['private_key_file_pwd'] = os.environ['SNOWFLAKE_PRIVATE_KEY_PASSPHRASE']
    else:
        params['authenticator'] = os.environ.get('SNOWFLAKE_AUTHENTICATOR', 'externalbrowser')
        if os.environ.get('SNOWFLAKE_PASSWORD'):
            params['password'] = os.environ['SNOWFLAKE_PASSWORD']
    if database:
        params['database'] = identifier(os.environ.get('SNOWFLAKE_DATABASE', 'ELIO_ASSESSMENT'))
        params['warehouse'] = identifier(os.environ.get('SNOWFLAKE_WAREHOUSE', 'ELIO_ASSESSMENT_WH'))
    return snowflake.connector.connect(**params)
