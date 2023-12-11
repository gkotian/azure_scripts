import os
from azure.keyvault.secrets import SecretClient
from azure.identity import ClientSecretCredential

key_vault = input('Enter the name of the key vault: ')
key_vault_url = f"https://{key_vault}.vault.azure.net"

tenant_id = input('Enter the tenant ID: ')
client_id = input('Enter the client ID: ')
client_secret = input('Enter the client secret: ')

credential = ClientSecretCredential(
    tenant_id=tenant_id, client_id=client_id, client_secret=client_secret)
client = SecretClient(vault_url=key_vault_url, credential=credential)

secret_name = input('Enter the name of the secret to fetch: ')
secret_value = client.get_secret(secret_name)

print(f"The value of '{secret_name}' in key vault '{key_vault}' is '{secret_value.value}'")
