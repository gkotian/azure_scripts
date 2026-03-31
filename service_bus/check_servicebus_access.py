#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "azure-servicebus",
#     "azure-identity",
# ]
# ///

"""Check whether an Azure AD app has access to read
from a Service Bus topic subscription."""

from azure.identity import ClientSecretCredential
from azure.servicebus import ServiceBusClient

TENANT_ID = "my-tenant-id"
CLIENT_ID = "my-client-id"
CLIENT_SECRET = "my-client-secret"


def main():
    namespace = input("Service Bus namespace: ").strip()
    topic = input("Topic name: ").strip()
    subscription = input("Subscription name: ").strip()

    fqn = f"{namespace}.servicebus.windows.net"

    credential = ClientSecretCredential(
        tenant_id=TENANT_ID,
        client_id=CLIENT_ID,
        client_secret=CLIENT_SECRET,
    )

    try:
        client = ServiceBusClient(fqn, credential)
        receiver = client.get_subscription_receiver(
            topic_name=topic,
            subscription_name=subscription,
            max_wait_time=5,
        )
        with receiver:
            msgs = receiver.receive_messages(
                max_message_count=1, max_wait_time=5
            )
            if msgs:
                print(f"\nSUCCESS: Received {len(msgs)} message(s).")
                for m in msgs:
                    print(f"  Body: {str(m)}")
                    # Don't complete — leave message on the queue
            else:
                print(
                    "\nSUCCESS: Connected and listening. "
                    "No messages in the subscription right now."
                )
    except Exception as e:
        print(f"\nFAILED: {e}")
    finally:
        client.close()


if __name__ == "__main__":
    main()
