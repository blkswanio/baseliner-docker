import sys
import os
import sys
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


def write_dataframe(client, dataframe, mid, tags, collection):
    tags.update({ 'mid': mid })
    df = dataframe.set_index(pd.DatetimeIndex([datetime.now()]))
    saved = client.write_points(df, collection, tags, protocol='line')
    if not saved:
        print("Failed to save data to DB")
        sys.exit(1)


def find_npb_cpu_st_tests():
    result = list()
    filenames = os.listdir('/root/')
    for filename in filenames:
        if filename.startswith('npb') and filename.endswith('ST.csv'):
            result.append(filename)
    return result


def find_npb_cpu_mt_tests():
    result = list()
    filenames = os.listdir('/root/')
    for filename in filenames:
        if filename.startswith('npb') and filename.endswith('MT.csv'):
            result.append(filename)
    return result


def find_fio_benchmark_result_file(iodepth, type, device):
    filenames = os.listdir('/root/')
    for filename in filenames:
        if type in filename and "io{}".format(iodepth) in filename and filename.endswith("{}.csv".format(device)):
            return filename
    return None


if __name__ == "__main__":
    client = connect_to_db('root', 'root', 'blackswan', 'scruffy.soe.ucsc.edu')

    mid = sys.argv[1]
    nsockets = int(sys.argv[2])

    npb_cpu_st_results = find_npb_cpu_st_tests()
    for sno in range(0, nsockets):
        socketid = "socket{}".format(sno)
        for res in npb_cpu_st_results:
            if socketid in res:
                dataframe = pd.read_csv(res)
                write_dataframe(client, dataframe, mid, { 'socket': sno }, 'npb_cpu_st')

    npb_cpu_mt_results = find_npb_cpu_mt_tests()
    for sno in range(0, nsockets):
        socketid = "socket{}".format(sno)
        for res in npb_cpu_mt_results:
            if socketid in res:
                dataframe = pd.read_csv(res)
                write_dataframe(client, dataframe, mid, { 'socket': sno }, 'npb_cpu_mt')

    for sno in range(0, nsockets):
        filename = "membench_out_socket{}_dvfs.csv".format(sno)
        dataframe = pd.read_csv(filename)
        write_dataframe(client, dataframe, mid, { 'socket': sno }, 'membench')

    
    for sno in range(0, nsockets):
        filename = "stream_out_socket{}_dvfs.csv".format(sno)
        dataframe = pd.read_csv(filename)
        write_dataframe(client, dataframe, mid, { 'socket': sno }, 'stream')

    print('COMPLETED SUCCESSFULLY !')