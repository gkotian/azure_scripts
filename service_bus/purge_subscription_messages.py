#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "azure-servicebus",
#   "azure-identity",
# ]
# ///
from azure.servicebus import ServiceBusClient, ServiceBusSubQueue
from azure.servicebus.management import ServiceBusAdministrationClient
from azure.identity import DefaultAzureCredential
import time


def prompt(label, default=None):
    suffix = f" [{default}]" if default else ""
    while True:
        value = input(f"{label}{suffix}: ").strip()
        if value:
            return value
        if default is not None:
            return default
        print("A value is required.")


def prompt_yes_no(label, default=False):
    default_str = "Y/n" if default else "y/N"
    while True:
        value = input(f"{label} [{default_str}]: ").strip().lower()
        if not value:
            return default
        if value in ("y", "yes"):
            return True
        if value in ("n", "no"):
            return False
        print("Please answer y or n.")


def get_service_bus_namespace(dev_or_prod):
    return "TODO"


def purge():
    while True:
        dev_or_prod = prompt("Environment (dev/prod)").lower()
        if dev_or_prod in ("dev", "prod"):
            break
        print("Please enter 'dev' or 'prod'.")

    namespace = get_service_bus_namespace(dev_or_prod)
    fqdn = f"{namespace}.servicebus.windows.net"
    topic_name = prompt("Topic name")
    subscription_name = prompt("Subscription name")
    purge_dlq = prompt_yes_no(
        "Purge the dead-letter queue instead of the main subscription?",
        default=False,
    )

    target = "dead-letter queue" if purge_dlq else "main subscription"

    credential = DefaultAzureCredential()

    admin = ServiceBusAdministrationClient(
        fully_qualified_namespace=fqdn, credential=credential
    )
    with admin:
        props = admin.get_subscription_runtime_properties(
            topic_name, subscription_name
        )
    message_count = (
        props.dead_letter_message_count
        if purge_dlq
        else props.active_message_count
    )

    print()
    print("Summary")
    print("-------")
    print(f"  Environment:    {dev_or_prod}")
    print(f"  Namespace:      {namespace}")
    print(f"  Topic:          {topic_name}")
    print(f"  Subscription:   {subscription_name}")
    print(f"  Target:         {target}")
    print(f"  Messages to delete: {message_count}")
    print()
    if message_count == 0:
        print(f"The {target} is empty. Nothing to do.")
        return
    if not prompt_yes_no(
        f"Permanently delete all messages from the {target}?",
        default=False,
    ):
        print("Aborted.")
        return

    client = ServiceBusClient(
        fully_qualified_namespace=fqdn, credential=credential
    )
    with client:
        receiver_kwargs = {
            "topic_name": topic_name,
            "subscription_name": subscription_name,
        }
        if purge_dlq:
            receiver_kwargs["sub_queue"] = ServiceBusSubQueue.DEAD_LETTER

        receiver = client.get_subscription_receiver(**receiver_kwargs)
        with receiver:
            msg_num = 0
            start_time = time.time()
            while True:
                messages = receiver.receive_messages(
                    max_message_count=100, max_wait_time=5
                )
                if not messages:
                    break
                for msg in messages:
                    msg_num += 1
                    receiver.complete_message(msg)
                elapsed = time.time() - start_time
                print(
                    f"Messages cleared so far: {msg_num} "
                    f"(in {elapsed:.2f} seconds)",
                    end="\r",
                    flush=True,
                )

    print()
    print(f"{msg_num} messages cleared from the {target}.")


if __name__ == "__main__":
    purge()
