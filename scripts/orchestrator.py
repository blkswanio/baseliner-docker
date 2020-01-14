import sys
import os
import json
import subprocess
import sys
import hashlib
from datetime import datetime

import pandas as pd
from influxdb import DataFrameClient


BASE_DIR = '/root/'

def connect_to_db(user, password, dbname, host, port=8086):
    client = DataFrameClient(host, port, user, password, dbname)
    if client.ping():
        print('Connection: SUCCESS\n')
        return client
    else:
        print('Connection: FAILED\n')
        sys.exit(1)


def write_df(client, df, machine_df, tags, collection):
    df = pd.concat([df, machine_df], axis=1)
    df = df.set_index(pd.DatetimeIndex([datetime.now()]))
    saved = client.write_points(df, collection, tags, protocol='line')
    if not saved:
        print("Failed to save data to DB")
        sys.exit(1)


def find_npb_cpu_st_tests():
    result = list()
    filenames = os.listdir(BASE_DIR)
    for filename in filenames:
        if filename.startswith('npb') and filename.endswith('ST.csv'):
            result.append(os.path.join(BASE_DIR, filename))
    return result


def find_npb_cpu_mt_tests():
    result = list()
    filenames = os.listdir(BASE_DIR)
    for filename in filenames:
        if filename.startswith('npb') and filename.endswith('MT.csv'):
            result.append(os.path.join(BASE_DIR, filename))
    return result


def find_fio_benchmark_result_file(iodepth, type, device):
    filenames = os.listdir(BASE_DIR)
    for filename in filenames:
        if type in filename and "io{}".format(iodepth) in filename and filename.endswith("{}.csv".format(device)):
            return os.path.join(BASE_DIR, filename)
    return None


def read_disks():
    f = open(os.path.join(BASE_DIR, "disks.txt"))
    data = f.read()
    f.close()
    if not data:
        return list()
    return data.split("\n")[:-1]


def fetch_machine_info():
    facter_output = subprocess.check_output(["facter", "--json"]).decode("utf-8")
    return json.loads(facter_output)


if __name__ == "__main__":
    nsockets = int(sys.argv[1])
    # Connect to InfluxDB instance and return client instance
    user = os.environ['BLACKSWAN_USER']
    passwd = os.environ['BLACKSWAN_PASSWD']
    database = os.environ['BLACKSWAN_DB']
    host = os.environ['BLACKSWAN_HOST']
    client = connect_to_db(user, passwd, database, host)

    # Generate a machine df from the fetched the machine information
    machine_info = fetch_machine_info()
    machine_df = pd.DataFrame([machine_info])

    # Gather and Save NAS CPU ST benchmarks
    npb_cpu_st_results = find_npb_cpu_st_tests()
    for sno in range(0, nsockets):
        socketid = "socket{}".format(sno)
        for res in npb_cpu_st_results:
            if socketid in res:
                df = pd.read_csv(res)
                df['size'] = str(df['size'])
                write_df(client, df, machine_df, { 'socket': str(sno) }, 'npb_cpu_st')

    # Gather and Save NAS CPU MT benchmarks
    npb_cpu_mt_results = find_npb_cpu_mt_tests()
    for sno in range(0, nsockets):
        socketid = "socket{}".format(sno)
        for res in npb_cpu_mt_results:
            if socketid in res:
                df = pd.read_csv(res)
                df['size'] = str(df['size'])
                write_df(client, df, machine_df, { 'socket': str(sno) }, 'npb_cpu_mt')

    # Gather and Save membench benchmarks
    for sno in range(0, nsockets):
        filename = "membench_out_socket{}_dvfs.csv".format(sno)
        df = pd.read_csv(os.path.join(BASE_DIR, filename))
        write_df(client, df, machine_df, { 'socket': str(sno) }, 'membench')

        filename = "membench_out_socket{}_nodvfs.csv".format(sno)
        df = pd.read_csv(os.path.join(BASE_DIR, filename))
        write_df(client, df, machine_df, { 'socket': str(sno) }, 'membench')

    # Gather and Save stream benchmarks
    for sno in range(0, nsockets):
        filename = "stream_out_socket{}_dvfs.csv".format(sno)
        df = pd.read_csv(os.path.join(BASE_DIR, filename))
        write_df(client, df, machine_df, { 'socket': str(sno) }, 'stream')

        filename = "stream_out_socket{}_nodvfs.csv".format(sno)
        df = pd.read_csv(os.path.join(BASE_DIR, filename))
        write_df(client, df, machine_df, { 'socket': str(sno) }, 'stream')

    # Gather and Save fio benchmarks
    for device in read_disks():
        iodepth_1_read_seq_benchmark = find_fio_benchmark_result_file(1, 'read_seq', device)
        iodepth_4096_read_seq_benchmark = find_fio_benchmark_result_file(4096, 'read_seq', device)

        if iodepth_1_read_seq_benchmark:
            df = pd.read_csv(iodepth_1_read_seq_benchmark)
            write_df(client, df, machine_df, { 'type': 'read_seq', 'io_depth': 1, 'device': device }, 'fio')

        if iodepth_4096_read_seq_benchmark:
            df = pd.read_csv(iodepth_4096_read_seq_benchmark)
            write_df(client, df, machine_df, { 'type': 'read_seq', 'io_depth': 4096, 'device': device }, 'fio')

        iodepth_1_read_rand_benchmark = find_fio_benchmark_result_file(1, 'read_rand', device)
        iodepth_4096_read_rand_benchmark = find_fio_benchmark_result_file(4096, 'read_rand', device)

        if iodepth_1_read_rand_benchmark:
            df = pd.read_csv(iodepth_1_read_rand_benchmark)
            write_df(client, df, machine_df, { 'type': 'read_rand', 'io_depth': 1, 'device': device }, 'fio')

        if iodepth_4096_read_rand_benchmark:
            df = pd.read_csv(iodepth_4096_read_rand_benchmark)
            write_df(client, df, machine_df, { 'type': 'read_rand', 'io_depth': 4096, 'device': device }, 'fio')

        iodepth_1_write_seq_benchmark = find_fio_benchmark_result_file(1, 'write_seq', device)
        iodepth_4096_write_seq_benchmark = find_fio_benchmark_result_file(4096, 'write_seq', device)

        if iodepth_1_write_seq_benchmark:
            df = pd.read_csv(iodepth_1_write_seq_benchmark)
            write_df(client, df, machine_df, { 'type': 'write_seq', 'io_depth': 1, 'device': device }, 'fio')

        if iodepth_4096_write_seq_benchmark:
            df = pd.read_csv(iodepth_4096_write_seq_benchmark)
            write_df(client, df, machine_df, { 'type': 'write_seq', 'io_depth': 4096, 'device': device }, 'fio')

        iodepth_1_write_rand_benchmark = find_fio_benchmark_result_file(1, 'write_rand', device)
        iodepth_4096_write_rand_benchmark = find_fio_benchmark_result_file(4096, 'write_rand', device)

        if iodepth_1_write_rand_benchmark:
            df = pd.read_csv(iodepth_1_write_rand_benchmark)
            write_df(client, df, machine_df, { 'type': 'write_rand', 'io_depth': 1, 'device': device }, 'fio')

        if iodepth_4096_write_rand_benchmark:
            df = pd.read_csv(iodepth_4096_write_rand_benchmark)
            write_df(client, df, machine_df, { 'type': 'write_rand', 'io_depth': 4096, 'device': device }, 'fio')

    print('COMPLETED SUCCESSFULLY !')
