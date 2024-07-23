#!/usr/bin/python3
import paramiko
import argparse
import time

def wait_for_prompt(channel, prompt, timeout=10):
    """Warten auf eine bestimmte Eingabeaufforderung."""
    end_time = time.time() + timeout
    output = ""
    while time.time() < end_time:
        if channel.recv_ready():
            output += channel.recv(9999).decode()
            if prompt in output:
                return output
        time.sleep(0.1)
    raise Exception(f"Prompt '{prompt}' not found in output:\n{output}")

def ssh_execute_command(hostname, port, username, password, command):
    try:
        print(f"Connecting to {hostname} on port {port} as {username}...")

        # Erstellen Sie ein Transport-Objekt
        transport = paramiko.Transport((hostname, port))
        transport.get_security_options().kex = ['diffie-hellman-group14-sha1']
        transport.connect(username=username, password=password)

        # Erstellen Sie ein SSH-Client-Objekt und verwenden Sie den bestehenden Transport
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client._transport = transport

        print("Connection established, opening shell...")

        # Öffnen Sie einen Kanal
        channel = client.invoke_shell()
        time.sleep(1)  # Warten Sie kurz, damit der Kanal geöffnet wird

        # Warten auf die Eingabeaufforderung "Enter Ctrl-Y to begin."
        print("Waiting for 'Enter Ctrl-Y to begin.' prompt...")
        output = wait_for_prompt(channel, "Enter Ctrl-Y to begin.")
        print(output)  # Debug-Ausgabe der Eingabeaufforderung

        print("Sending Ctrl-Y...")
        channel.send('\x19')  # \x19 ist der ASCII-Code für Ctrl-Y
        time.sleep(1)  # Warten Sie kurz

        # Senden Sie die Enter-Taste nach Ctrl-Y
        channel.send('\n')
        time.sleep(1)  # Warten Sie kurz

        # Warten auf die Eingabeaufforderung des Switches
        print("Waiting for switch prompt...")
        output = wait_for_prompt(channel, "#")
        print(output)  # Debug-Ausgabe der Eingabeaufforderung

        # Deaktivieren des Paging
        print("Disabling paging...")
        channel.send('terminal length 0\n')
        time.sleep(1)  # Warten Sie kurz, damit der Befehl ausgeführt wird

        # Senden Sie das Kommando
        print("Sending command...")
        channel.send(command + '\n')
        time.sleep(2)  # Warten Sie kurz, damit der Befehl ausgeführt wird

        # Lesen Sie die Ausgabe des Befehls
        output = ""
        while channel.recv_ready():
            output += channel.recv(9999).decode()
            time.sleep(1)  # Kleine Pause, um mehr Daten zu sammeln

        print("Command executed, closing connection...")
        return output
    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        transport.close()
        print("Connection closed.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Execute a command on a remote host via SSH.')
    parser.add_argument('--hostname', required=True, help='Hostname or IP address of the remote host')
    parser.add_argument('--port', type=int, default=22, help='SSH port, default is 22')
    parser.add_argument('--username', required=True, help='Username for SSH login')
    parser.add_argument('--password', required=True, help='Password for SSH login')
    parser.add_argument('--command', required=True, help='Command to execute on the remote host')

    args = parser.parse_args()

    hostname = args.hostname
    port = args.port
    username = args.username
    password = args.password
    command = args.command

    output = ssh_execute_command(hostname, port, username, password, command)
    if output:
        print(output)

