import argparse
import json
import os
import platform
import signal
import subprocess
import tarfile

import requests
import time
import urllib.request
import zipfile
from collections import OrderedDict
from datetime import datetime
from pathlib import Path

from psutil import process_iter

NODE = "./cardano-node"
CLI = "./cardano-cli"
ROOT_TEST_PATH = ""
CARDANO_NODE_PATH = ""
CARDANO_NODE_TESTS_PATH = ""


def set_repo_paths():
    global CARDANO_NODE_PATH
    global CARDANO_NODE_TESTS_PATH
    global ROOT_TEST_PATH

    ROOT_TEST_PATH = Path.cwd()

    os.chdir("cardano-node")
    CARDANO_NODE_PATH = Path.cwd()

    os.chdir("..")
    os.chdir("database-sync-tests")
    CARDANO_NODE_TESTS_PATH = Path.cwd()
    os.chdir("..")


def git_get_commit_sha_for_tag_no(tag_no):
    global jData
    url = "https://api.github.com/repos/input-output-hk/cardano-node/tags"
    response = requests.get(url)
    if response.ok:
        jData = json.loads(response.content)
    else:
        response.raise_for_status()

    for tag in jData:
        if tag.get('name') == tag_no:
            return tag.get('commit').get('sha')

    print(f" ===== ERROR: The specified tag_no - {tag_no} - was not found ===== ")
    print(json.dumps(jData, indent=4, sort_keys=True))
    return None


def git_get_hydra_eval_link_for_commit_sha(commit_sha):
    global jData
    url = f"https://api.github.com/repos/input-output-hk/cardano-node/commits/{commit_sha}/status"
    response = requests.get(url)
    if response.ok:
        jData = json.loads(response.content)
    else:
        response.raise_for_status()

    for status in jData.get('statuses'):
        if "hydra.iohk.io/eval" in status.get("target_url"):
            return status.get("target_url")

    print(f" ===== ERROR: There is not eval link for the provided commit_sha - {commit_sha} =====")
    print(json.dumps(jData, indent=4, sort_keys=True))
    return None


def get_hydra_build_download_url(eval_url, os_type):
    global eval_jData, build_jData

    expected_os_types = ["windows", "linux", "macos"]
    if os_type not in expected_os_types:
        raise Exception(
            f" ===== ERROR: provided os_type - {os_type} - not expected - {expected_os_types}")

    headers = {'Content-type': 'application/json'}
    eval_response = requests.get(eval_url, headers=headers)

    eval_jData = json.loads(eval_response.content)

    if eval_response.ok:
        eval_jData = json.loads(eval_response.content)
    else:
        eval_response.raise_for_status()

    for build_no in eval_jData.get("builds"):
        build_url = f"https://hydra.iohk.io/build/{build_no}"
        build_response = requests.get(build_url, headers=headers)
        if build_response.ok:
            build_jData = json.loads(build_response.content)
        else:
            build_response.raise_for_status()

        if os_type.lower() == "windows":
            if build_jData.get("job") == "cardano-node-win64":
                return f"https://hydra.iohk.io/build/{build_no}/download/1/cardano-node-1.24.0-win64.zip"
        elif os_type.lower() == "linux":
            if build_jData.get("job") == "cardano-node-linux":
                return f"https://hydra.iohk.io/build/{build_no}/download/1/cardano-node-1.24.0-linux.tar.gz"
        elif os_type.lower() == "macos":
            if build_jData.get("job") == "cardano-node-macos":
                return f"https://hydra.iohk.io/build/{build_no}/download/1/cardano-node-1.24.0-macos.tar.gz"

    print(f" ===== ERROR: No build has found for the required os_type - {os_type} - {eval_url} ===")
    return None


def get_and_extract_node_files(tag_no):
    print(" - get and extract the pre-built node files")
    os.chdir(Path(CARDANO_NODE_TESTS_PATH))
    platform_system, platform_release, platform_version = get_os_type()

    commit_sha = git_get_commit_sha_for_tag_no(tag_no)
    eval_url = git_get_hydra_eval_link_for_commit_sha(commit_sha)

    print(f"commit_sha  : {commit_sha}")
    print(f"eval_url    : {eval_url}")

    if "linux" in platform_system.lower():
        download_url = get_hydra_build_download_url(eval_url, "linux")
        get_and_extract_linux_files(download_url)


def get_and_extract_linux_files(download_url):
    os.chdir(Path(CARDANO_NODE_TESTS_PATH))
    current_directory = os.getcwd()
    print(f" - current_directory: {current_directory}")

    archive_name = download_url.split("/")[-1].strip()

    print(f"archive_name: {archive_name}")
    print(f"download_url: {download_url}")

    urllib.request.urlretrieve(download_url, Path(current_directory) / archive_name)

    print(f" ------ listdir (before archive extraction): {os.listdir(current_directory)}")
    tf = tarfile.open(Path(current_directory) / archive_name)
    tf.extractall(Path(current_directory))
    print(f" - listdir (after archive extraction): {os.listdir(current_directory)}")


def delete_node_files():
    os.chdir(Path(CARDANO_NODE_TESTS_PATH))
    for p in Path(".").glob("cardano-*"):
        print(f" === deleting file: {p}")
        p.unlink(missing_ok=True)


def get_node_config_files(env):
    os.chdir(Path(CARDANO_NODE_TESTS_PATH))
    urllib.request.urlretrieve(
        "https://hydra.iohk.io/job/Cardano/iohk-nix/cardano-deployment/latest-finished/download/1/"
        + env
        + "-config.json",
        env + "-config.json",
    )
    urllib.request.urlretrieve(
        "https://hydra.iohk.io/job/Cardano/iohk-nix/cardano-deployment/latest-finished/download/1/"
        + env
        + "-byron-genesis.json",
        env + "-byron-genesis.json",
    )
    urllib.request.urlretrieve(
        "https://hydra.iohk.io/job/Cardano/iohk-nix/cardano-deployment/latest-finished/download/1/"
        + env
        + "-shelley-genesis.json",
        env + "-shelley-genesis.json",
    )
    urllib.request.urlretrieve(
        "https://hydra.iohk.io/job/Cardano/iohk-nix/cardano-deployment/latest-finished/download/1/"
        + env
        + "-topology.json",
        env + "-topology.json",
    )


def set_node_socket_path_env_var():
    socket_path = (Path(CARDANO_NODE_TESTS_PATH) / "db" / "node.socket").expanduser().absolute()
    os.environ["CARDANO_NODE_SOCKET_PATH"] = str(socket_path)


def get_os_type():
    return [platform.system(), platform.release(), platform.version()]


def get_testnet_value():
    env = vars(args)["environment"]
    if env == "mainnet":
        return "--mainnet"
    elif env == "testnet":
        return "--testnet-magic 1097911063"
    elif env == "staging":
        return "--testnet-magic 633343913"
    elif env == "shelley_qa":
        return "--testnet-magic 3"
    else:
        return None


def wait_for_node_to_start(tag_no):
    # when starting from clean state it might take ~30 secs for the cli to work
    # when starting from existing state it might take >5 mins for the cli to work (opening db and
    # replaying the ledger)
    tip = get_current_tip(tag_no, True)
    count = 0
    while tip == 1:
        time.sleep(10)
        count += 1
        tip = get_current_tip(tag_no, True)
        if count >= 540:  # 90 mins
            print(" **************  ERROR: waited 90 mins and CLI is still not usable ********* ")
            print(f"      TIP: {get_current_tip(tag_no)}")
            exit(1)
    print(f"************** CLI became available after: {count * 10} seconds **************")
    return count * 10


def get_current_tip(tag_no, wait=False):
    # tag_no should have this format: 1.23.0, 1.24.1, etc
    os.chdir(Path(CARDANO_NODE_TESTS_PATH))

    if int(tag_no.split(".")[1]) < 24:
        cmd = CLI + " shelley query tip " + get_testnet_value()
    else:
        cmd = CLI + " query tip " + get_testnet_value()
    try:
        output = (
            subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT)
                .decode("utf-8")
                .strip()
        )
        output_json = json.loads(output)
        return int(output_json["blockNo"]), output_json["headerHash"], int(output_json["slotNo"])
    except subprocess.CalledProcessError as e:
        if wait:
            return int(e.returncode)
        else:
            raise RuntimeError(
                "command '{}' return with error (code {}): {}".format(
                    e.cmd, e.returncode, " ".join(str(e.output).split())
                )
            )


def get_node_version():
    os.chdir(Path(CARDANO_NODE_TESTS_PATH))
    try:
        cmd = CLI + " --version"
        output = (
            subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT)
                .decode("utf-8")
                .strip()
        )
        cardano_cli_version = output.split("git rev ")[0].strip()
        cardano_cli_git_rev = output.split("git rev ")[1].strip()
        return str(cardano_cli_version), str(cardano_cli_git_rev)
    except subprocess.CalledProcessError as e:
        raise RuntimeError(
            "command '{}' return with error (code {}): {}".format(
                e.cmd, e.returncode, " ".join(str(e.output).split())
            )
        )

def start_node_unix(env, tag_no):
    os.chdir(Path(CARDANO_NODE_TESTS_PATH))
    current_directory = Path.cwd()

    cmd = (
        f"{NODE} run --topology {env}-topology.json --database-path "
        f"{Path(CARDANO_NODE_TESTS_PATH) / 'db'} "
        f"--host-addr 0.0.0.0 --port 3000 --config "
        f"{env}-config.json --socket-path /db/node.socket"
    )

    logfile = open("logfile.log", "w+")
    print(f"cmd: {cmd}")

    try:
        subprocess.run(cmd.split(" "), stdout=logfile, stderr=subprocess.PIPE)
        print("waiting for db folder to be created")
        count = 0
        while not os.path.isdir(current_directory / "db"):
            time.sleep(3)
            count += 1
            if count > 10:
                print("ERROR: waited 30 seconds and the DB folder was not created yet")
                break

        secs_to_start = wait_for_node_to_start(tag_no)
        print("DB folder was created")
        print(f" - listdir current_directory: {os.listdir(current_directory)}")
        print(f" - listdir db: {os.listdir(current_directory / 'db')}")
        return secs_to_start
    except subprocess.CalledProcessError as e:
        raise RuntimeError(
            "command '{}' return with error (code {}): {}".format(
                e.cmd, e.returncode, " ".join(str(e.output).split())
            )
        )


def stop_node():
    for proc in process_iter():
        if "cardano-node" in proc.name():
            print(f" --- Killing the `cardano-node` process - {proc}")
            proc.send_signal(signal.SIGTERM)
            proc.terminate()
            proc.kill()
    time.sleep(10)
    for proc in process_iter():
        if "cardano-node" in proc.name():
            print(f" --- ERROR: `cardano-node` process is still active - {proc}")


def get_current_date_time():
    now = datetime.now()
    return now.strftime("%d/%m/%Y %H:%M:%S")


def get_file_creation_date(path_to_file):
    return time.ctime(os.path.getmtime(path_to_file))

def main():
    global NODE
    global CLI

    secs_to_start1, secs_to_start2 = 0, 0

    set_repo_paths()
    print(f"root_test_path          : {ROOT_TEST_PATH}")
    print(f"cardano_node_path       : {CARDANO_NODE_PATH}")
    print(f"cardano_node_tests_path : {CARDANO_NODE_TESTS_PATH}")

    env = vars(args)["environment"]
    print(f"env: {env}")

    set_node_socket_path_env_var()

    node_tag = str(vars(args)["node_tag"]).strip()

    print(f"node_tag: {node_tag}")


    platform_system, platform_release, platform_version = get_os_type()
    print(f"platform: {platform_system, platform_release, platform_version}")

    print("move to 'CARDANO_NODE_TESTS_PATH'")
    os.chdir(Path(CARDANO_NODE_TESTS_PATH))

    print("get the required node files")
    get_node_config_files(env)

    print("===================================================================================")
    print(f"=========================== Start sync using node_tag: {node_tag} ==================")
    print("===================================================================================")
    get_and_extract_node_files(node_tag)

    print(" --- node version ---")
    cardano_cli_version1, cardano_cli_git_rev1 = get_node_version()
    print(f"  - cardano_cli_version1: {cardano_cli_version1}")
    print(f"  - cardano_cli_git_rev1: {cardano_cli_git_rev1}")

    print(f"   ======================= Start node using node_tag: {node_tag} ====================")
    start_sync_time1 = get_current_date_time()
    secs_to_start1 = start_node_unix(env, node_tag)

    print("move to 'cardano_node_tests_path/scripts'")
    os.chdir(Path(CARDANO_NODE_TESTS_PATH) / "sync_tests")
    current_directory = Path.cwd()

    print(f" - sync_tests listdir: {os.listdir(current_directory)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Execute basic sync test\n\n")

    parser.add_argument(
        "-nt", "--node_tag", help="node tag to be used with db-sync"
    )

    parser.add_argument(
        "-e",
        "--environment",
        help="the environment on which to run the tests - shelley_qa or mainnet.",
    )

    args = parser.parse_args()

    main()