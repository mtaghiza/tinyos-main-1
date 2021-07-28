import sqlite3


def setup_and_verify_metadata_db(conn):
    c = conn.cursor()
    c.execute('''
    SELECT COUNT(*) FROM sqlite_master WHERE name='deployment_metadata';
    ''')
    deployment_meta_table_present = c.fetchone()[0]
    if deployment_meta_table_present == 0:
        c.execute('''
            CREATE TABLE deployment_metadata(id INTEGER PRIMARY KEY, name TEXT,
            set_up_date INTEGER, download_interval INTEGER,
             last_download INTEGER, network_db_name TEXT, active INTEGER);
                  ''')
        print("TABLE ADDED: deployment")
    else:
        print("TEST PASS: deployment table present")

    c.execute('''
    SELECT COUNT(*) FROM sqlite_master WHERE name = 'bacon_metadata';
    ''')
    bacon_metadata_present = c.fetchone()[0]
    if bacon_metadata_present == 0:
        c.execute('''
        CREATE TABLE bacon_metadata(bacon_id INTEGER PRIMARY KEY, deployment_id INTEGER, patch_id INTEGER,
         ACTIVE INTEGER, CHANNEL INTEGER);
        ''')
        print("TABLE ADDED: bacon_metadata")
    else:
        print("TEST PASS: bacon_metadata table present")

    c.execute('''
     SELECT COUNT(*) FROM sqlite_master WHERE name = 'toast_metadata';
     ''')
    toast_metadata_present = c.fetchone()[0]
    if toast_metadata_present == 0:
        c.execute('''
         CREATE TABLE toast_metadata(toast_id INTEGER PRIMARY KEY, bacon_id INTEGER);
         ''')
        print("TABLE ADDED: toast_metadata")
    else:
        print("TEST PASS: toast_metadata table present")

    c.execute('''
        SELECT COUNT(*) FROM sqlite_master WHERE name = 'sensor_metadata';
        ''')
    sensor_metadata_present = c.fetchone()[0]

    if sensor_metadata_present == 0:
        c.execute('''
            CREATE TABLE sensor_metadata(sensor_id INTEGER PRIMARY KEY, type TEXT, toast_id INTEGER,
             ACTIVE INTEGER, DEPTH REAL, X_COORDINATE REAL, Y_COORDINATE REAL);
            ''')
        print("TABLE ADDED: sensor_metadata")
    else:
        print("TEST PASS: sensor_metadata table present")
    conn.commit()


def add_sample_data(conn):
    c = conn.cursor()
    sample_deployments = [(0, 'Olin Hall Text Deployment', 1611108399, 7, 1611118399, 'database0.db', 1),
                          (1, 'USDA Agricultural Farm', 1611008399, 7, 1611118399, 'database1.db', 1),
                          (2, 'Ecuador Rain Forest', 1511008229, 14, 1611118299, 'database2.db', 1),
                          (3, 'Mongolian Highland', 1511008229, 14, 1611118299, 'database2.db', 1),
                          (4, 'Newfoundland Field Station', 1511008229, 21, 1611118299, 'database2.db', 1)]

    sample_bacon_meta = [(0x0110, 1, 1, 1, 0), (0x0111, 1, 1, 1, 0), (0x0112, 1, 1, 1, 0), (0x0113, 1, 1, 1, 0),
                         (0x0114, 1, 1, 1, 0), (0x0115, 1, 1, 1, 0),
                         (0x0116, 1, 2, 1, 1), (0x0117, 1, 2, 1, 1), (0x0118, 1, 2, 1, 1), (0x0119, 1, 2, 1, 1),
                         (0x011A, 1, 2, 1, 0),
                         (0x0120, 2, 1, 1, 0), (0x0121, 2, 1, 1, 0), (0x0122, 2, 1, 1, 0), (0x0123, 2, 1, 1, 0),
                         (0x0124, 2, 1, 1, 0), (0x0125, 2, 1, 1, 0),
                         (0x0126, 2, 2, 1, 1), (0x0127, 2, 2, 1, 1), (0x0128, 2, 2, 1, 1), (0x0129, 2, 2, 1, 1),
                         (0x012A, 2, 2, 1, 1), (0x012B, 2, 2, 0, 1)
                         ]
    sample_sensor_meta = [
        (0x101, 'temperature', 0x510, 1, 0.10, -110.56423222, 39.449999),
        (0x102, 'temperature', 0x510, 1, 0.10, -110.56423222, 39.449989),
        (0x201, 'moisture', 0x510, 1, 0.10, -110.56423222, 39.449989),
        (0x202, 'moisture', 0x510, 1, 0.10, -110.56423222, 39.449989),
        (0x103, 'temperature', 0x511, 1, 0.10, -110.56423222, 39.449999),
        (0x104, 'temperature', 0x511, 1, 0.10, -110.56423222, 39.449989),
        (0x203, 'moisture', 0x511, 1, 0.10, -110.56423222, 39.449989),
        (0x204, 'moisture', 0x511, 1, 0.10, -110.56423222, 39.449989),
        (0x105, 'temperature', 0x512, 1, 0.10, -110.56423222, 39.449999),
        (0x106, 'temperature', 0x512, 1, 0.10, -110.56423222, 39.449989),
        (0x205, 'moisture', 0x512, 1, 0.10, -110.56423222, 39.449989),
        (0x206, 'moisture', 0x512, 1, 0.10, -110.56423222, 39.449989),
        (0x107, 'temperature', 0x513, 1, 0.10, -110.56423222, 39.449999),
        (0x108, 'temperature', 0x513, 1, 0.10, -110.56423222, 39.449989),
        (0x207, 'moisture', 0x513, 1, 0.10, -110.56423222, 39.449989),
        (0x208, 'moisture', 0x513, 1, 0.10, -110.56423222, 39.449989),
    ]
    sample_toast_meta = [
        (0x510, 0x110),
        (0x511, 0x111),
        (0x512, 0x112),
        (0x513, 0x120)
    ]
    c.execute('SELECT COUNT(*) FROM deployment_metadata')
    empty = c.fetchone()[0]
    if empty == 0:
        c.executemany('''INSERT INTO deployment_metadata VALUES (?,?,?,?,?,?,?)''', sample_deployments)
        c.executemany('''INSERT INTO bacon_metadata VALUES (?,?,?,?,?)''', sample_bacon_meta)
        c.executemany('''INSERT INTO toast_metadata VALUES (?,?)''', sample_toast_meta)
        c.executemany('''INSERT INTO sensor_metadata VALUES (?,?,?,?,?,?,?)''', sample_sensor_meta)

    conn.commit()


def get_node_information_by_deployment(conn, did):
    c = conn.cursor()
    c.execute('''SELECT X.bacon_id, COUNT(distinct X.toast_id), COUNT(distinct sensor_metadata.sensor_id)
    FROM (SELECT bacon_metadata.bacon_id AS bacon_id, toast_metadata.toast_id AS toast_id 
    FROM bacon_metadata 
    LEFT JOIN toast_metadata ON bacon_metadata.bacon_id=toast_metadata.bacon_id 
    WHERE bacon_metadata.deployment_id=?) AS X
    LEFT JOIN sensor_metadata ON X.toast_id=sensor_metadata.toast_id
    GROUP BY X.bacon_id
    ''', (did,))
    return c.fetchall()


def get_deployment_info_all(conn):
    c = conn.cursor()
    c.execute('SELECT * FROM deployment_metadata')
    return c.fetchall()


def get_deployment_info_by_id(conn, id):
    c = conn.cursor()
    c.execute('SELECT * FROM deployment_metadata WHERE id=?', (id,))
    return c.fetchone()


# return the name and id of existing deployments
def get_deployment_name_and_id(conn):
    c = conn.cursor()
    c.execute('SELECT name, id FROM deployment_metadata')
    return c.fetchall()


# return the name of existing deployments
def get_deployment_name(conn):
    c = conn.cursor()
    c.execute('SELECT name FROM deployment_metadata')
    return c.fetchall()


def get_bacon_id_patchid_status_by_deployment(conn, deployment_id):
    c = conn.cursor()
    c.execute('SELECT bacon_id, patch_id, active FROM bacon_metadata WHERE deployment_id=?', (deployment_id,))
    return c.fetchall()


def get_no_motes_by_deployment(conn, id):
    return conn.execute('SELECT COUNT(*) FROM bacon_metadata WHERE deployment_id=?', (id,)).fetchone()


def get_no_sensors_by_deployment(conn, id):
    return conn.execute('''SELECT COUNT(DISTINCT S.sensor_id) 
    FROM toast_metadata AS T, bacon_metadata AS B, sensor_metadata as S
    WHERE B.deployment_id=? AND T.bacon_id=B.bacon_id AND S.toast_id = T.toast_id''', (id,)).fetchone()


def get_sensor_info_by_node_id(conn, node_id):
    return conn.execute('''SELECT S.toast_id, S.sensor_id, S.type, S.ACTIVE, S.DEPTH, S.X_COORDINATE, S.Y_COORDINATE FROM 
    (SELECT * FROM (bacon_metadata B LEFT JOIN toast_metadata T ON B.bacon_id=T.bacon_id) WHERE B.bacon_id=?) AS TB LEFT JOIN sensor_metadata AS S ON TB.toast_id=S.toast_id ORDER BY S.toast_id 
    ''', (node_id,)).fetchall()


def recursive_delete_by_node_id(conn, node_id):
    conn.execute('''DELETE FROM sensor_metadata WHERE sensor_id IN 
    (SELECT sensor_id FROM (toast_metadata T LEFT JOIN sensor_metadata S on S.toast_id=T.toast_id) WHERE T.bacon_id=?)
    ''', (node_id,))
    conn.execute('''DELETE FROM toast_metadata WHERE bacon_id=?''', (node_id,))
    conn.execute('''DELETE FROM bacon_metadata WHERE bacon_id=?''', (node_id,))
    conn.commit()


def recursive_delete_by_toast_id(conn, toast_id):
    conn.execute('''DELETE from sensor_metadata WHERE toast_id=?''', (toast_id,))
    conn.execute('''DELETE from toast_metadata WHERE toast_id=?''', (toast_id,))
    conn.commit()


def delete_by_sensor_id(conn, sensor_id):
    conn.execute('''DELETE from sensor_metadata WHERE sensor_id=?''', (sensor_id,))
    conn.commit()


def get_toast_info_all(conn):
    return conn.execute('''SELECT * from toast_metadata''').fetchall()


def get_sensor_info_all(conn):
    return conn.execute('''SELECT * from sensor_metadata''').fetchall()


def get_bacon_info_all(conn):
    return conn.execute('''SELECT * from bacon_metadata''').fetchall()


if __name__ == '__main__':
    try:
        conn = sqlite3.connect("ehon.db")
        setup_and_verify_metadata_db(conn)
        print("SUCCESS: metadata database passed integrity check")
        add_sample_data(conn)
        # print(get_deployment_info_all(conn))
        # print(get_deployment_name_and_id(conn))
        # print(get_bacon_id_patchid_status_by_deployment(conn, 1))
        # print(get_no_motes_by_deployment(conn, 1))
        # print(get_no_sensors_by_deployment(conn, 1))
        # print(get_node_information_by_deployment(conn, 1))
        # print(get_sensor_info_by_node_id(conn, 272))
        print("BEFORE DELETE")
        print(get_deployment_info_all(conn))
        print(get_bacon_info_all(conn))
        print(get_toast_info_all(conn))
        print(get_sensor_info_all(conn))

        # delete_by_sensor_id(conn, 257)

        print("AFTER DELETE")
        print(get_deployment_info_all(conn))
        print(get_bacon_info_all(conn))
        print(get_toast_info_all(conn))
        print(get_sensor_info_all(conn))

        conn.close()
        print("connection closed")
    except KeyboardInterrupt:
        print("keyboard interrupt. gracefully shutdown")
        conn.close()
