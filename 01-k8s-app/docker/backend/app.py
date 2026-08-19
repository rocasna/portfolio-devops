from flask import Flask, jsonify
from google.cloud.sql.connector import Connector, IPTypes

app = Flask(__name__)

@app.route('/')
def inicio():
    return "¡Servidor Flask funcionando con éxito!"

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        "status": "UP",
        "message": "Aplicación saludable"
    }), 200

@app.route('/data', methods=['GET'])
def obtener_datos():
    lista_ejemplo = [
        {"id": 1, "nombre": "Usuario 1", "rol": "Admin"},
        {"id": 2, "nombre": "Usuario 2", "rol": "Editor"}
    ]
    return jsonify(lista_ejemplo)

connector = Connector()

def getconn():
    conn = connector.connect(
        "fase-b-505318:europe-west1:dev-terraform-module-db",
        "pymysql",
        user="dev-terraform-module-sa@fase-b-505318.iam.gserviceaccount.com",
        db="information_schema",
        enable_iam_auth=True,
        ip_type=IPTypes.PRIVATE,
    )
    return conn

def check_db():
    conn = getconn()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT 1")
            return cursor.fetchone()[0]
    finally:
        conn.close()

@app.route('/db-status', methods=['GET'])
def db_status():
    try:
        resultado = check_db()
        return jsonify({"status": "conectado", "resultado": resultado}), 200
    except Exception as e:
        return jsonify({"status": "error", "detalle": str(e)}), 500