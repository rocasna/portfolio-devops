from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/')
def inicio():
    return "¡Servidor Flask funcionando con éxito!"

# Nuevo endpoint de salud para monitoreo y liveness/readiness probes
@app.route('/api/health', methods=['GET'])
def health_check():
    return jsonify({
        "status": "UP",
        "message": "Aplicación saludable"
    }), 200

@app.route('/api/data', methods=['GET'])
def obtener_datos():
    lista_ejemplo = [
        {"id": 1, "nombre": "Usuario 1", "rol": "Admin"},
        {"id": 2, "nombre": "Usuario 2", "rol": "Editor"}
    ]
    return jsonify(lista_ejemplo)
