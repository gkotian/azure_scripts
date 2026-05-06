#!/usr/bin/env python

from typing import Optional

import os
import subprocess


class AZError(Exception):
    pass


def az(*args, file='', **popen_kwargs) -> Optional[str]:
    args = list(args)
    args.insert(0, '/usr/bin/az')
    popen_kwargs['stdout'] = subprocess.PIPE
    popen_kwargs['stderr'] = subprocess.PIPE
    proc = subprocess.Popen(args, **popen_kwargs)
    (stdout, stderr) = proc.communicate()
    str_stdout = stdout.decode(errors='replace')
    str_stderr = stderr.decode(errors='replace')
    if proc.returncode != 0:
        raise AZError(' '.join(args), str_stderr)

    if file != '':
        with open(file, 'w') as f:
            f.write(str_stdout.rstrip('\n'))
    else:
        return str_stdout.rstrip('\n')


def add_permission(app_id, scope, role, tmp_dir):
    args = ['role', 'assignment', 'create', f'--scope={scope}',
        f'--role={role}', f'--assignee={app_id}']
    rsp_file = os.path.join(tmp_dir,
        f'{app_id}-role-assignment-create-rsp.json')
    az(*args, file=rsp_file)


def confirm_planned_changes(app_id, dev_or_prod, access_type, resource_group,
        namespace, assignments, is_human_user):
    principal_type = 'human user' if is_human_user else 'app registration'

    print()
    print("Summary of planned changes:")
    print(f"  Assignee: {app_id} ({principal_type})")
    print(f"  Environment: {dev_or_prod}")
    print(f"  Permission type: {access_type}")
    print(f"  Resource group: {resource_group}")
    print(f"  Service bus namespace: {namespace}")
    print("  Role assignments to create:")
    for role, description, scope in assignments:
        print(f"    - Role: {role}")
        print(f"      Target: {description}")
        print(f"      Scope: {scope}")
    print()

    answer = input("Proceed? [Y/n]: ").strip().lower()
    return answer in ('', 'y', 'yes')


def get_service_bus_details(dev_or_prod):
    return "TODO", "TODO", "TODO"


def run(app_id, dev_or_prod, topics, is_human_user=False,
        access_type='receiver'):
    subscription_id, resource_group, namespace = get_service_bus_details(
        dev_or_prod)

    if access_type not in ('receiver', 'sender'):
        raise ValueError("access_type must be 'receiver' or 'sender'.")

    # Use topics = ['*'] to grant namespace-wide receiver permission.
    # This is only allowed for human users on the dev service bus.
    namespace_wide_receiver = topics == ['*']
    if '*' in topics and not namespace_wide_receiver:
        raise ValueError("'*' cannot be combined with other topics.")
    if namespace_wide_receiver and access_type != 'receiver':
        raise ValueError(
            "Namespace-wide permission (topics=['*']) is only supported for "
            "receiver access.")
    if namespace_wide_receiver:
        if not is_human_user:
            raise ValueError(
                "Namespace-wide receiver permission (topics=['*']) is only "
                "allowed for human users, not app registrations.")
        if dev_or_prod != 'dev':
            raise ValueError(
                "Namespace-wide receiver permission (topics=['*']) is only "
                "allowed for the dev service bus.")

    tmp_dir = '/tmp'

    namespace_scope = f'/subscriptions/{subscription_id}/resourceGroups/{resource_group}/providers/Microsoft.ServiceBus/namespaces/{namespace}'
    assignments = []

    if access_type == 'receiver':
        namespace_role = 'Reader'
        assignments.append(
            (namespace_role, f"service bus namespace '{namespace}'",
                namespace_scope))

        receiver_role = 'Azure Service Bus Data Receiver'
        if namespace_wide_receiver:
            assignments.append(
                (receiver_role,
                    f"service bus namespace '{namespace}' (all topics)",
                    namespace_scope))
        else:
            for topic in topics:
                topic_scope = namespace_scope + f'/topics/{topic}'
                assignments.append(
                    (receiver_role,
                        f"topic '{topic}' under service bus namespace "
                        f"'{namespace}'",
                        topic_scope))
    else:
        sender_role = 'Azure Service Bus Data Sender'
        for topic in topics:
            topic_scope = namespace_scope + f'/topics/{topic}'
            assignments.append(
                (sender_role,
                    f"topic '{topic}' under service bus namespace '{namespace}'",
                    topic_scope))

    if not confirm_planned_changes(app_id, dev_or_prod, access_type,
            resource_group, namespace, assignments, is_human_user):
        print("Cancelled.")
        return

    for role, description, scope in assignments:
        add_permission(app_id, scope, role, tmp_dir)
        print(f"Added role '{role}' for {description}")


def main():
    app_id = input("Enter app ID (or user's object ID for human users): ")
    if not app_id.strip():
        print("Error: app ID is required.")
        return
    app_id = app_id.strip()

    dev_or_prod = input("Enter environment (dev/prod): ").strip().lower()
    if dev_or_prod not in ('dev', 'prod'):
        print("Error: environment must be 'dev' or 'prod'.")
        return

    is_human = input("Is this a human user? (yes/no): ").strip().lower()
    if is_human not in ('yes', 'no'):
        print("Error: please answer 'yes' or 'no'.")
        return
    is_human_user = is_human == 'yes'

    access_type = input(
        "Enter permission type (receiver/sender) [receiver]: ").strip().lower()
    if not access_type:
        access_type = 'receiver'
    if access_type not in ('receiver', 'sender'):
        print("Error: permission type must be 'receiver' or 'sender'.")
        return

    if access_type == 'receiver' and is_human_user and dev_or_prod == 'dev':
        prompt = "Enter topic names (comma-separated, or * for all topics): "
    else:
        prompt = "Enter topic names (comma-separated): "

    topics_input = input(prompt)
    topics = [t.strip() for t in topics_input.split(',') if t.strip()]

    if '*' in topics and len(topics) > 1:
        print("Error: '*' cannot be combined with other topics.")
        return

    if '*' in topics and access_type != 'receiver':
        print("Error: '*' is only supported for receiver permission.")
        return

    if not topics:
        print("No topics specified. Exiting.")
        return

    run(app_id, dev_or_prod, topics, is_human_user, access_type)


if __name__ == '__main__':
    main()
