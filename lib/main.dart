import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

List<CameraDescription> camarasDisponibles = [];

// ====================================================================
// CREDENCIALES DE SUPABASE
// ====================================================================
const String supabaseUrl = 'https://rmtplgckvtcnijlobcfj.supabase.co';
const String supabaseAnonKey = 'sb_publishable_dz7S8AKNzrPjck79Tupx4w_YHvsxAge';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    camarasDisponibles = await availableCameras();
  } catch (e) {
    debugPrint('Error cámaras: $e');
  }
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const MiEscanerApp());
}

class MiEscanerApp extends StatelessWidget {
  const MiEscanerApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: '.SF Pro Text',
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.light(primary: Color(0xFF8B1D1D), surface: Colors.white),
      ),
      home: const PantallaEscaner(),
    );
  }
}

class MedicamentoInfo {
  final String nombre;
  final String sustancia;
  final String categoria;
  final List<String> indicacionesEnfermedades;
  final List<String> combinacionesSeguras;
  final List<String> medicamentosAEvitar;
  final List<String> sintomasQueAlivia;
  final Map<String, String> riesgosCronicos;
  final String contraindicacionEmbarazo;
  final String riesgoAlcohol;
  final String recomendacionEstomago;
  final bool afectaConduccion;
  final List<String> familiaAlergias;
  final List<String> enfermedadesIneficaces;
  final List<Map<String, String>> preguntasFrecuentes;
  final String alternativaSegura;
  final String reglaIngesta;

  MedicamentoInfo({
    required this.nombre, required this.sustancia, required this.categoria,
    required this.indicacionesEnfermedades, required this.combinacionesSeguras,
    required this.medicamentosAEvitar, required this.sintomasQueAlivia,
    required this.riesgosCronicos, required this.contraindicacionEmbarazo,
    required this.riesgoAlcohol, required this.recomendacionEstomago,
    required this.afectaConduccion, required this.familiaAlergias,
    required this.enfermedadesIneficaces, required this.preguntasFrecuentes,
    required this.alternativaSegura, required this.reglaIngesta,
  });
}

class PantallaEscaner extends StatefulWidget {
  const PantallaEscaner({super.key});
  @override
  State<PantallaEscaner> createState() => _PantallaEscanerState();
}

class _PantallaEscanerState extends State<PantallaEscaner> {
  String modoActivo = 'Consulta General';
  CameraController? controllerCamara;
  bool camaraLista = false;
  bool flashEncendido = false;
  bool procesandoFoto = false;

  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final SupabaseClient _supabase = Supabase.instance.client;

  static const Color colorVino = Color(0xFF8B1D1D); 
  static const Color colorVerdeIOS = Color(0xFF34C759); 
  static const Color colorNaranjaIOS = Color(0xFFFF9500); 
  static const Color colorAzulIOS = Color(0xFF007AFF);
  static const Color fondoGrisIOS = Color(0xFFF2F2F7);
  static const Color separadorIOS = Color(0xFFE5E5EA);
  static const Color textoSecundario = Color(0xFF8E8E93);

  // ====================================================================
  // DICCIONARIOS PERFIL BASE
  // ====================================================================
  final Map<String, Map<String, bool>> enfermedades = {
    '1. Cardiovasculares': {'Hipertensión Arterial': false, 'Insuficiencia Cardíaca': false, 'Cardiopatía Isquémica': false, 'Arritmias crónicas': false},
    '2. Metabólicas y Endocrinas': {'Diabetes Mellitus': false, 'Hipotiroidismo / Hipertiroidismo': false, 'Dislipidemia Crónica': false},
    '3. Respiratorias': {'Asma': false, 'EPOC': false},
    '4. Renales y Hepáticas': {'Insuficiencia Renal Crónica': false, 'Insuficiencia Hepática / Cirrosis': false, 'Hígado Graso severo': false},
    '5. Gastrointestinales': {'Gastritis Crónica / Úlceras': false, 'Colitis Ulcerosa / Crohn': false, 'Reflujo Gastroesofágico severo': false},
    '6. Neurológicas y Psiquiátricas': {'Epilepsia': false, 'Enfermedad de Parkinson': false, 'Ansiedad / Depresión crónicas': false},
    '7. Autoinmunes y Oftalmológicas': {'Artritis Reumatoide': false, 'Lupus Eritematoso Sistémico': false, 'Glaucoma': false},
  };

  final Map<String, Map<String, bool>> estadosFisiologicos = {
    'Etapas y Condición Corporal': {'Embarazo': false, 'Lactancia Materna': false, 'Adulto Mayor (+65 años)': false, 'Obesidad Severa': false, 'Desnutrición / Bajo Peso': false},
    'Hábitos de Alto Impacto': {'Tabaquismo Habitual': false, 'Consumo Crónico de Alcohol': false}
  };

  final Map<String, Map<String, bool>> alergias = {
    'Antibióticos': {'Penicilinas (Amoxicilina, Ampicilina)': false, 'Cefalosporinas': false, 'Sulfamidas (Bactrim)': false, 'Macrólidos (Azitromicina, Eritromicina)': false},
    'Analgésicos y Antiinflamatorios': {'AINEs (Ibuprofeno, Ketorolaco, etc.)': false, 'Aspirina (Ácido Acetilsalicílico)': false, 'Opiáceos (Tramadol, Morfina)': false, 'Paracetamol': false},
    'Otros Compuestos Comunes': {'Medios de Contraste (Yodo)': false, 'Lactosa (Excipiente)': false, 'Tartrazina / Amarillo 5': false, 'Fibratos': false, 'Ácidos Biliares': false}
  };

  final Map<String, Map<String, bool>> medicamentosDiarios = {
    'Para Presión y Corazón': {'Losartán / Telmisartán': false, 'Amlodipino / Nifedipino': false, 'Aspirina Protect (100mg)': false, 'Atorvastatina / Pravastatina': false},
    'Para Metabolismo y Azúcar': {'Metformina': false, 'Insulina (Glargina / NPH)': false, 'Levotiroxina (Eutirox)': false},
    'Psiquiátricos y Neurológicos': {'Antidepresivos (Sertralina, Fluoxetina)': false, 'Ansiolíticos (Clonazepam, Alprazolam)': false, 'Anticonvulsivos (Valproato, Carbamazepina)': false},
    'Uso Diario Diverso': {'Protectores Gástricos (Omeprazol)': false, 'Inhaladores (Salbutamol, Fluticasona)': false, 'Anticonceptivos Orales': false}
  };

  // ====================================================================
  // NUEVOS DICCIONARIOS PERFIL TEMPORAL
  // ====================================================================
  final Map<String, Map<String, bool>> sintomasTemporales = {
    'Dolor y Fiebre': {'Cefalea / Dolor de cabeza': false, 'Fiebre / Escalofríos': false, 'Dolor muscular / Articular': false, 'Cólicos menstruales': false},
    'Gastrointestinal y Hepático': {'Náuseas / Vómito': false, 'Acidez / Reflujo': false, 'Diarrea / Infección': false, 'Pesadez biliar / Dolor hepático': false},
    'Respiratorio y Alergias': {'Tos / Congestión nasal': false, 'Infección de garganta': false, 'Alergia / Erupción cutánea': false, 'Ojos llorosos / Estornudos': false},
  };

  final Map<String, Map<String, bool>> medicamentosPreviosTemporales = {
    'Analgésicos y Antiinflamatorios': {'Paracetamol': false, 'Ibuprofeno': false, 'Aspirina': false, 'Naproxeno / Ketorolaco': false},
    'Gastrointestinales': {'Omeprazol / Pantoprazol': false, 'Antiácidos (Aluminio/Magnesio)': false, 'Subsalicilato de bismuto': false, 'Loperamida': false},
    'Antigripales y Alergias': {'Loratadina / Cetirizina': false, 'Clorfenamina / Fenilefrina': false},
  };

  final Map<String, Map<String, bool>> factoresRiesgoTemporales = {
    'Consumo Reciente': {'Ingesta de alcohol (Últimas 24h)': false, 'Alta ingesta de cafeína / Energéticas': false, 'Comida muy grasosa o pesada': false},
    'Estado Físico Actual': {'Estómago vacío / Ayuno prolongado': false, 'Deshidratación severa': false, 'Fatiga extrema / Insomnio': false},
    'Actividades Próximas': {'Voy a conducir o manejar maquinaria': false, 'Exposición prolongada al sol': false},
  };

  @override
  void initState() {
    super.initState();
    _inicializarCamara();
  }

  Future<void> _inicializarCamara() async {
    if (camarasDisponibles.isNotEmpty) {
      controllerCamara = CameraController(camarasDisponibles[0], ResolutionPreset.high, enableAudio: false);
      await controllerCamara!.initialize();
      if (!mounted) return;
      setState(() => camaraLista = true);
    }
  }

  Future<void> _conmutarFlash() async {
    if (controllerCamara != null && controllerCamara!.value.isInitialized) {
      setState(() => flashEncendido = !flashEncendido);
      await controllerCamara!.setFlashMode(flashEncendido ? FlashMode.torch : FlashMode.off);
    }
  }

  void _mostrarAlertaNoEncontrado(String titulo, String mensaje) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
        content: Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(mensaje)),
        actions: [CupertinoDialogAction(isDefaultAction: true, child: const Text('Entendido', style: TextStyle(color: colorVino)), onPressed: () => Navigator.pop(context))],
      ),
    );
  }

  Future<void> _tomarFoto() async {
    if (controllerCamara == null || !controllerCamara!.value.isInitialized || procesandoFoto) return;
    setState(() => procesandoFoto = true);
    try {
      final XFile foto = await controllerCamara!.takePicture();
      final InputImage inputImage = InputImage.fromFilePath(foto.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      if (recognizedText.text.trim().isEmpty) {
        if (!mounted) return;
        _mostrarAlertaNoEncontrado('Sin texto', 'Enfoca bien el empaque.');
        return;
      }
      final med = await _consultarMedicamentoEnSupabase(recognizedText.text);
      if (!mounted) return;
      if (med == null) {
        _mostrarAlertaNoEncontrado('No identificado', 'No coincide con BD.');
      } else {
        _mostrarModalAnalisis(med);
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => procesandoFoto = false);
    }
  }

  Future<MedicamentoInfo?> _consultarMedicamentoEnSupabase(String textoOcr) async {
    final textoUpper = textoOcr.toUpperCase();
    try {
      final List<dynamic> palabrasRows = await _supabase.from('ocr_palabras_clave').select('medicamento_id, palabra_clave');
      int? idMedicamentoEncontrado;
      for (final row in palabrasRows) {
        if (textoUpper.contains((row['palabra_clave'] as String).toUpperCase())) {
          idMedicamentoEncontrado = row['medicamento_id'] as int;
          break;
        }
      }
      if (idMedicamentoEncontrado == null) return null;

      final data = await _supabase
          .from('medicamentos')
          .select('''*, medicamento_indicaciones(indicacion), interacciones_a_evitar(descripcion_riesgo), combinaciones_seguras(descripcion_combinacion), medicamento_sintomas(sintoma), riesgos_enfermedades_cronicas(enfermedad, detalle_riesgo), medicamento_alergias(familia_alergia), enfermedades_ineficaces(enfermedad), preguntas_frecuentes(pregunta, respuesta)''')
          .eq('id', idMedicamentoEncontrado)
          .single();

      final Map<String, String> riesgosMap = {};
      for (final item in (data['riesgos_enfermedades_cronicas'] as List)) {
        riesgosMap[item['enfermedad'].toString()] = item['detalle_riesgo'].toString();
      }

      return MedicamentoInfo(
        nombre: '${data['nombre_comercial']} ${data['concentracion']}',
        sustancia: data['sustancia_activa'],
        categoria: '${data['categoria_farmacologica']} (${data['forma_farmaceutica']})',
        indicacionesEnfermedades: (data['medicamento_indicaciones'] as List).map((e) => e['indicacion'].toString()).toList(),
        combinacionesSeguras: (data['combinaciones_seguras'] as List).map((e) => e['descripcion_combinacion'].toString()).toList(),
        medicamentosAEvitar: (data['interacciones_a_evitar'] as List).map((e) => e['descripcion_riesgo'].toString()).toList(),
        sintomasQueAlivia: (data['medicamento_sintomas'] as List).map((e) => e['sintoma'].toString()).toList(),
        riesgosCronicos: riesgosMap,
        contraindicacionEmbarazo: data['contraindicacion_embarazo'] ?? '',
        riesgoAlcohol: data['riesgo_alcohol'] ?? '',
        recomendacionEstomago: data['recomendacion_estomago'] ?? '',
        afectaConduccion: data['afecta_conduccion'] ?? false,
        familiaAlergias: (data['medicamento_alergias'] as List).map((e) => e['familia_alergia'].toString()).toList(),
        enfermedadesIneficaces: (data['enfermedades_ineficaces'] as List?)?.map((e) => e['enfermedad'].toString()).toList() ?? [],
        preguntasFrecuentes: (data['preguntas_frecuentes'] as List?)?.map((e) => {'pregunta': e['pregunta'].toString(), 'respuesta': e['respuesta'].toString()}).toList() ?? [],
        alternativaSegura: data['alternativa_segura'] ?? 'No hay alternativa registrada.',
        reglaIngesta: data['regla_ingesta'] ?? 'No hay reglas de ingesta registradas.',
      );
    } catch (e) {
      return null;
    }
  }

  void _mostrarModalAnalisis(MedicamentoInfo med) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: const BoxDecoration(color: fondoGrisIOS, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(width: 36, height: 5, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2.5))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(med.nombre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black87)),
                            const SizedBox(height: 2),
                            Text('${med.sustancia} • ${med.categoria}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textoSecundario)),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Color(0xFFC7C7CC), size: 28), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    children: [
                      if (modoActivo == 'Consulta General') ..._buildContenidoConsultaGeneral(med)
                      else if (modoActivo == 'Perfil Base') ..._buildContenidoPerfilBaseResult(med)
                      else ..._buildContenidoPerfilTemporalResult(med),
                      
                      const SizedBox(height: 22),
                      _cabeceraSeccion('PREGUNTAS FRECUENTES'),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2))],
                        ),
                        child: med.preguntasFrecuentes.isEmpty 
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No hay preguntas frecuentes registradas para este medicamento.', style: TextStyle(color: Colors.black87, fontSize: 13)),
                          )
                        : Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: Column(
                              children: med.preguntasFrecuentes.map((faq) {
                                return ExpansionTile(
                                  title: Text(faq['pregunta']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                                  iconColor: colorVino, collapsedIconColor: textoSecundario,
                                  leading: const Icon(CupertinoIcons.sparkles, color: colorVino, size: 20),
                                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  children: [Align(alignment: Alignment.centerLeft, child: Text(faq['respuesta']!, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4)))],
                                );
                              }).toList(),
                            ),
                          ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Listo', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ========================================================
  // LÓGICA CLÍNICA: PERFIL BASE
  // ========================================================
  List<Widget> _buildContenidoPerfilBaseResult(MedicamentoInfo med) {
    List<Map<String, dynamic>> alertasInteracciones = [];
    List<Map<String, dynamic>> alertasCronicas = [];
    List<Map<String, dynamic>> alertasAlergias = [];
    List<Map<String, dynamic>> alertasFisiologicas = [];
    
    bool esRojo = false;
    bool esAmarillo = false;

    // Evaluar Interacciones
    medicamentosDiarios.forEach((cat, lista) {
      lista.forEach((medDiario, activa) {
        if (activa) {
          if (med.nombre.toLowerCase().contains(medDiario.toLowerCase().split(' ')[0]) || med.sustancia.toLowerCase().contains(medDiario.toLowerCase().split(' ')[0])) {
            alertasInteracciones.add({'tipo': 'Riesgo de Sobredosis', 'texto': 'Tu tratamiento ya incluye $medDiario. Tomar este fármaco duplicará el efecto.', 'critico': true});
            esRojo = true;
          }
          if (med.medicamentosAEvitar.any((evitar) => evitar.toLowerCase().contains(medDiario.toLowerCase().split(' ')[0]))) {
            alertasInteracciones.add({'tipo': 'Interacción Peligrosa', 'texto': 'Interfiere severamente con tu uso diario de $medDiario.', 'critico': true});
            esRojo = true;
          }
        }
      });
    });

    // Evaluar Crónicas
    enfermedades.forEach((cat, lista) {
      lista.forEach((enfermedad, activa) {
        if (activa && med.riesgosCronicos.containsKey(enfermedad)) {
          alertasCronicas.add({'tipo': 'Impacto en $enfermedad', 'texto': med.riesgosCronicos[enfermedad]!, 'critico': true});
          esRojo = true;
        }
      });
    });

    // Evaluar Alergias
    alergias.forEach((cat, lista) {
      lista.forEach((alergia, activa) {
        if (activa && med.familiaAlergias.contains(alergia)) {
          alertasAlergias.add({'tipo': 'Alergia Severa', 'texto': 'Declaraste alergia a: $alergia. Riesgo de crisis alérgica cruzada.', 'critico': true});
          esRojo = true;
        }
      });
    });

    // Evaluar Fisiológicas
    if (estadosFisiologicos['Etapas y Condición Corporal']!['Embarazo']! && med.contraindicacionEmbarazo.isNotEmpty) {
      alertasFisiologicas.add({'tipo': 'Embarazo', 'texto': med.contraindicacionEmbarazo, 'critico': false});
      esAmarillo = true;
    }
    if (estadosFisiologicos['Etapas y Condición Corporal']!['Adulto Mayor (+65 años)']!) {
      alertasFisiologicas.add({'tipo': 'Ajuste Metabólico por Edad', 'texto': 'Tus riñones procesan más lento. Se recomienda iniciar con dosis mínima.', 'critico': false});
      esAmarillo = true;
    }
    if (estadosFisiologicos['Hábitos de Alto Impacto']!['Consumo Crónico de Alcohol']! && med.riesgoAlcohol.isNotEmpty) {
      alertasFisiologicas.add({'tipo': 'Sinergia Tóxica con Alcohol', 'texto': med.riesgoAlcohol, 'critico': false});
      esAmarillo = true;
    }

    String textSemaforo = esRojo ? 'USO CONTRAINDICADO (PELIGRO)' : (esAmarillo ? 'USO CON PRECAUCIÓN / AJUSTE' : 'USO SEGURO');
    Color colorSemaforo = esRojo ? colorVino : (esAmarillo ? colorNaranjaIOS : colorVerdeIOS);
    IconData iconSemaforo = esRojo ? CupertinoIcons.clear_circled_solid : (esAmarillo ? CupertinoIcons.exclamationmark_triangle_fill : CupertinoIcons.checkmark_seal_fill);

    return [
      _cabeceraSeccion('1. SEMÁFORO DE VIABILIDAD CLÍNICA'),
      _tarjetaSemaforoBig(textSemaforo, colorSemaforo, iconSemaforo),
      const SizedBox(height: 20),
      _cabeceraSeccion('2. INTERACCIONES FARMACOLÓGICAS'),
      alertasInteracciones.isNotEmpty ? _tarjetaListaAlertas(alertasInteracciones, colorVino, CupertinoIcons.clear_circled_solid) : _tarjetaAprobada('Sin interacciones con medicamentos de uso diario.', colorIcono: colorVerdeIOS),
      const SizedBox(height: 20),
      _cabeceraSeccion('3. IMPACTO EN ENFERMEDADES CRÓNICAS'),
      alertasCronicas.isNotEmpty ? _tarjetaListaAlertas(alertasCronicas, colorVino, CupertinoIcons.clear_circled_solid) : _tarjetaAprobada('Seguro: No agrava condiciones crónicas declaradas.', colorIcono: colorVerdeIOS),
      const SizedBox(height: 20),
      _cabeceraSeccion('4. SENSIBILIDAD Y ALERGIAS CRUZADAS'),
      alertasAlergias.isNotEmpty ? _tarjetaListaAlertas(alertasAlergias, colorVino, CupertinoIcons.clear_circled_solid) : _tarjetaAprobada('Apto: No hay alergias químicas cruzadas.', colorIcono: colorVerdeIOS),
      const SizedBox(height: 20),
      _cabeceraSeccion('5. AJUSTES POR ESTADOS FISIOLÓGICOS'),
      alertasFisiologicas.isNotEmpty ? _tarjetaListaAlertas(alertasFisiologicas, colorNaranjaIOS, CupertinoIcons.exclamationmark_triangle_fill) : _tarjetaAprobada('Estable: Dosis estándar apta para tu metabolismo.', colorIcono: colorVerdeIOS),
      const SizedBox(height: 20),
      _cabeceraSeccion('6. RECOMENDACIONES DE ACCIÓN Y ALTERNATIVAS'),
      _tarjetaInformativa(icono: CupertinoIcons.bandage_fill, colorIcono: colorAzulIOS, items: ['💡 Alternativa Médica Segura:\n${med.alternativaSegura}', '📋 Regla de Ingesta:\n${med.reglaIngesta}']),
    ];
  }

  // ========================================================
  // LÓGICA CLÍNICA: CONSULTA GENERAL
  // ========================================================
  List<Widget> _buildContenidoConsultaGeneral(MedicamentoInfo med) {
    return [
      _cabeceraSeccion('ENFERMEDADES ADECUADAS PARA EL MEDICAMENTO'),
      _tarjetaInformativa(icono: CupertinoIcons.check_mark_circled_solid, colorIcono: colorVerdeIOS, items: med.indicacionesEnfermedades.isNotEmpty ? med.indicacionesEnfermedades : ['No hay datos registrados.']),
      const SizedBox(height: 20),
      _cabeceraSeccion('CONDICIONES CON LAS QUE ES PELIGROSO TOMARLO'),
      _tarjetaInformativa(icono: CupertinoIcons.clear_circled_solid, colorIcono: colorVino, items: med.enfermedadesIneficaces.isNotEmpty ? med.enfermedadesIneficaces : ['No hay datos registrados.']),
      const SizedBox(height: 20),
      _cabeceraSeccion('EVITAR MEDICAMENTO SI TIENES ESTAS ALERGIAS'),
      _tarjetaInformativa(icono: CupertinoIcons.exclamationmark_triangle_fill, colorIcono: colorNaranjaIOS, items: med.familiaAlergias.isNotEmpty ? med.familiaAlergias : ['Ninguna alergia principal cruzada.']),
      const SizedBox(height: 20),
      _cabeceraSeccion('EVITAR ESTOS FÁRMACOS (RIESGO DE SOBREDOSIS/REACCIÓN)'),
      _tarjetaInformativa(icono: CupertinoIcons.bandage_fill, colorIcono: colorVino, items: med.medicamentosAEvitar.isNotEmpty ? med.medicamentosAEvitar : ['Ninguna interacción riesgosa registrada.']),
    ];
  }

  // ========================================================
  // LÓGICA CLÍNICA: PERFIL TEMPORAL REESTRUCTURADO (TODA LA INFO)
  // ========================================================
  List<Widget> _buildContenidoPerfilTemporalResult(MedicamentoInfo med) {
    List<Map<String, dynamic>> alertasMeds = [];
    List<Map<String, dynamic>> alertasFactores = [];
    
    // 1. SÍNTOMAS
    List<String> sintomasActivos = [];
    sintomasTemporales.forEach((cat, lista) { lista.forEach((sintoma, activo) { if (activo) sintomasActivos.add(sintoma); }); });
    
    List<String> sintomasTratados = sintomasActivos.where((s) => med.sintomasQueAlivia.contains(s)).toList();
    bool tieneSintomas = sintomasActivos.isNotEmpty;
    bool aliviaSintoma = sintomasTratados.isNotEmpty;

    // 2. MEDICAMENTOS PREVIOS HOY
    List<String> medsPreviosActivos = [];
    medicamentosPreviosTemporales.forEach((cat, lista) { lista.forEach((m, activo) { if (activo) medsPreviosActivos.add(m); }); });

    for (String m in medsPreviosActivos) {
      if (med.sustancia.toLowerCase().contains(m.split(' ')[0].toLowerCase()) || med.nombre.toLowerCase().contains(m.split(' ')[0].toLowerCase())) {
        alertasMeds.add({'tipo': 'Riesgo de Sobredosis', 'texto': 'Ya ingeriste $m hoy. Tomar esto duplicará peligrosamente la dosis.', 'critico': true});
      }
      if (med.medicamentosAEvitar.any((evitar) => evitar.toLowerCase().contains(m.split(' ')[0].toLowerCase()))) {
        alertasMeds.add({'tipo': 'Interacción Peligrosa', 'texto': 'Choca severamente con el $m que tomaste hace poco.', 'critico': true});
      }
    }

    // 3. FACTORES DE RIESGO TEMPORALES
    if (factoresRiesgoTemporales['Consumo Reciente']!['Ingesta de alcohol (Últimas 24h)']! && med.riesgoAlcohol.isNotEmpty) {
      alertasFactores.add({'tipo': 'Alcohol en el sistema', 'texto': med.riesgoAlcohol, 'critico': true});
    }
    if (factoresRiesgoTemporales['Estado Físico Actual']!['Estómago vacío / Ayuno prolongado']!) {
      alertasFactores.add({'tipo': 'Ayuno / Estómago Vacío', 'texto': med.recomendacionEstomago.isNotEmpty ? med.recomendacionEstomago : 'Puede causar irritación gástrica. Se sugiere tomar con alimentos.', 'critico': false});
    }
    if (factoresRiesgoTemporales['Actividades Próximas']!['Voy a conducir o manejar maquinaria']! && med.afectaConduccion) {
      alertasFactores.add({'tipo': 'Riesgo al Conducir', 'texto': 'Este fármaco altera los reflejos o causa somnolencia intensa.', 'critico': true});
    }
    if (factoresRiesgoTemporales['Consumo Reciente']!['Comida muy grasosa o pesada']! && med.recomendacionEstomago.toLowerCase().contains('grasa')) {
      alertasFactores.add({'tipo': 'Interacción con Alimentos', 'texto': 'Las comidas grasosas alteran drásticamente la absorción de este medicamento.', 'critico': false});
    }

    bool hayRiesgoCriticoMeds = alertasMeds.any((a) => a['critico'] == true);
    bool hayRiesgoCriticoFactores = alertasFactores.any((a) => a['critico'] == true);

    return [
      _cabeceraSeccion('1. COMPATIBILIDAD CON TUS SÍNTOMAS'),
      _tarjetaAprobada(
        !tieneSintomas ? 'No registraste ningún síntoma activo para evaluar.' 
        : (aliviaSintoma ? 'Indicado: Ayuda a aliviar ${sintomasTratados.join(", ")}.' 
        : 'No indicado: Este fármaco no sirve para los síntomas que marcaste.'),
        colorIcono: !tieneSintomas ? colorNaranjaIOS : (aliviaSintoma ? colorVerdeIOS : colorVino),
        icono: !tieneSintomas ? CupertinoIcons.info_circle_fill : (aliviaSintoma ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.clear_circled_solid)
      ),
      const SizedBox(height: 20),

      _cabeceraSeccion('2. RIESGO POR AUTOMEDICACIÓN PREVIA (HOY)'),
      alertasMeds.isNotEmpty 
          ? _tarjetaListaAlertas(alertasMeds, colorVino, CupertinoIcons.clear_circled_solid)
          : _tarjetaAprobada(
              medsPreviosActivos.isEmpty ? 'No has tomado otros medicamentos hoy.' : 'Seguro: No interfiere con los medicamentos que ya tomaste hoy.', 
              colorIcono: colorVerdeIOS, icono: CupertinoIcons.checkmark_seal_fill
            ),
      const SizedBox(height: 20),

      _cabeceraSeccion('3. FACTORES DE RIESGO TEMPORALES'),
      alertasFactores.isNotEmpty 
          ? _tarjetaListaAlertas(alertasFactores, hayRiesgoCriticoFactores ? colorVino : colorNaranjaIOS, hayRiesgoCriticoFactores ? CupertinoIcons.clear_circled_solid : CupertinoIcons.exclamationmark_triangle_fill)
          : _tarjetaAprobada(
              'Condición óptima: Tus hábitos recientes y estado actual no presentan riesgo.', 
              colorIcono: colorVerdeIOS, icono: CupertinoIcons.checkmark_seal_fill
            ),
    ];
  }

  // ========================================================
  // COMPONENTES UI: PANELES Y TARJETAS
  // ========================================================
  void _abrirPanelConfiguracion(String modoSeleccionado) {
    setState(() => modoActivo = modoSeleccionado);
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.90,
              decoration: const BoxDecoration(color: fondoGrisIOS, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
              child: Column(
                children: [
                  const SizedBox(height: 10), Container(width: 36, height: 5, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2.5))),
                  const SizedBox(height: 14),
                  Container(
                    width: 240, height: 36, padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(18)),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () { setModalState(() => modoActivo = 'Perfil Base'); setState(() => modoActivo = 'Perfil Base'); },
                            child: Container(decoration: BoxDecoration(color: modoActivo == 'Perfil Base' ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(16)), child: Center(child: Text('Perfil Base', style: TextStyle(fontSize: 13, fontWeight: modoActivo == 'Perfil Base' ? FontWeight.w600 : FontWeight.w500, color: modoActivo == 'Perfil Base' ? Colors.black87 : textoSecundario)))),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () { setModalState(() => modoActivo = 'Perfil Temporal'); setState(() => modoActivo = 'Perfil Temporal'); },
                            child: Container(decoration: BoxDecoration(color: modoActivo == 'Perfil Temporal' ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(16)), child: Center(child: Text('Perfil Temporal', style: TextStyle(fontSize: 13, fontWeight: modoActivo == 'Perfil Temporal' ? FontWeight.w600 : FontWeight.w500, color: modoActivo == 'Perfil Temporal' ? Colors.black87 : textoSecundario)))),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), children: modoActivo == 'Perfil Base' ? _buildFormPerfilBase(setModalState) : _buildFormPerfilTemporal(setModalState))),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorVino, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: () => Navigator.pop(context), child: const Text('Guardar y Escanear', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildFormPerfilBase(StateSetter setModalState) {
    return [
      _cabeceraSeccion('ENFERMEDADES CRÓNICAS PERMANENTES'), _tarjetaAgrupadaExpansible(categorias: enfermedades, setModalState: setModalState), const SizedBox(height: 20),
      _cabeceraSeccion('ESTADOS FISIOLÓGICOS Y HÁBITOS'), _tarjetaAgrupadaExpansible(categorias: estadosFisiologicos, setModalState: setModalState), const SizedBox(height: 20),
      _cabeceraSeccion('ALERGIAS CONOCIDAS A MEDICAMENTOS'), _tarjetaAgrupadaExpansible(categorias: alergias, setModalState: setModalState), const SizedBox(height: 20),
      _cabeceraSeccion('MEDICAMENTOS DE USO DIARIO / FIJO'), _tarjetaAgrupadaExpansible(categorias: medicamentosDiarios, setModalState: setModalState), const SizedBox(height: 20),
    ];
  }

  List<Widget> _buildFormPerfilTemporal(StateSetter setModalState) {
    return [
      _cabeceraSeccion('SÍNTOMAS O MALESTARES ACTIVOS'), _tarjetaAgrupadaExpansible(categorias: sintomasTemporales, setModalState: setModalState), const SizedBox(height: 20),
      _cabeceraSeccion('MEDICAMENTOS INGERIDOS HOY (AUTOMEDICACIÓN)'), _tarjetaAgrupadaExpansible(categorias: medicamentosPreviosTemporales, setModalState: setModalState), const SizedBox(height: 20),
      _cabeceraSeccion('FACTORES TEMPORALES DE RIESGO'), _tarjetaAgrupadaExpansible(categorias: factoresRiesgoTemporales, setModalState: setModalState), const SizedBox(height: 20),
    ];
  }

  Widget _tarjetaAgrupadaExpansible({required Map<String, Map<String, bool>> categorias, required StateSetter setModalState}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2))]),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Column(
          children: categorias.keys.map((categoria) {
            return ExpansionTile(
              title: Text(categoria, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
              iconColor: colorVino, collapsedIconColor: textoSecundario,
              children: categorias[categoria]!.keys.map((item) {
                final isChecked = categorias[categoria]![item] ?? false;
                return InkWell(
                  onTap: () { setModalState(() => categorias[categoria]![item] = !isChecked); setState(() => categorias[categoria]![item] = !isChecked); },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(child: Text(item, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                        Container(width: 20, height: 20, decoration: BoxDecoration(shape: BoxShape.circle, color: isChecked ? colorVino : Colors.transparent, border: Border.all(color: isChecked ? colorVino : const Color(0xFFC7C7CC), width: 2)), child: isChecked ? const Icon(Icons.check, size: 12, color: Colors.white) : null),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _tarjetaSemaforoBig(String texto, Color color, IconData icono) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3), width: 2)),
      child: Column(
        children: [
          Icon(icono, color: color, size: 48), const SizedBox(height: 10),
          Text(texto, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _tarjetaInformativa({required IconData icono, required Color colorIcono, required List<String> items}) {
    return Container(
      padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2))]),
      child: Column(
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icono, size: 18, color: colorIcono), const SizedBox(width: 12),
                Expanded(child: Text(item, style: const TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.4))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _tarjetaListaAlertas(List<Map<String, dynamic>> alertas, Color colorIcono, IconData iconoDefecto) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2))]),
      child: Column(
        children: alertas.asMap().entries.map((entry) {
          final idx = entry.key; final adv = entry.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(iconoDefecto, color: colorIcono, size: 22), const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(adv['tipo'], style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: colorIcono)),
                          const SizedBox(height: 4),
                          Text(adv['texto'], style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (idx < alertas.length - 1) const Divider(height: 1, indent: 46, color: separadorIOS),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _tarjetaAprobada(String texto, {Color? colorIcono, IconData? icono}) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2))]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono ?? CupertinoIcons.check_mark_circled_solid, color: colorIcono ?? colorVerdeIOS, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.35))),
        ],
      ),
    );
  }

  Widget _cabeceraSeccion(String texto) {
    return Padding(padding: const EdgeInsets.only(left: 6, bottom: 8), child: Text(texto, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textoSecundario, letterSpacing: 0.5)));
  }

  @override
  void dispose() {
    controllerCamara?.dispose(); _textRecognizer.close(); super.dispose();
  }

  // ========================================================
  // INTERFAZ DE CÁMARA
  // ========================================================
  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double anchoMarco = screenSize.width * 0.88;
    final double altoMarco = screenSize.height * 0.54;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (camaraLista && controllerCamara != null)
            SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: controllerCamara!.value.previewSize?.height ?? 1, height: controllerCamara!.value.previewSize?.width ?? 1, child: CameraPreview(controllerCamara!))))
          else const Center(child: CupertinoActivityIndicator(color: Colors.white, radius: 14)),
          ColorFiltered(
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.55), BlendMode.srcOut),
            child: Stack(children: [Container(decoration: const BoxDecoration(color: Colors.black, backgroundBlendMode: BlendMode.dstOut)), Center(child: Container(width: anchoMarco, height: altoMarco, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32))))]),
          ),
          Center(
            child: Container(
              width: anchoMarco, height: altoMarco,
              decoration: BoxDecoration(border: Border.all(color: procesandoFoto ? colorVerdeIOS : Colors.white.withOpacity(0.9), width: procesandoFoto ? 2.5 : 1.8), borderRadius: BorderRadius.circular(32)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Stack(
                  children: [
                    Align(alignment: Alignment.topCenter, child: Padding(padding: const EdgeInsets.only(top: 20), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), color: Colors.black.withOpacity(0.35), child: const Text('Enfoca la fórmula o empaque', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500))))))),
                    if (procesandoFoto)
                      Positioned.fill(child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6), child: Container(color: Colors.black.withOpacity(0.45), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [CupertinoActivityIndicator(color: Colors.white, radius: 16), SizedBox(height: 14), Text('Analizando...', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))])))),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(20), child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), color: Colors.black.withOpacity(0.35), child: Row(children: [Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: colorVerdeIOS)), const SizedBox(width: 8), Text(modoActivo, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))])))),
                  ClipRRect(borderRadius: BorderRadius.circular(22), child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: AnimatedContainer(duration: const Duration(milliseconds: 200), decoration: BoxDecoration(color: flashEncendido ? const Color(0xFFFFD60A).withOpacity(0.28) : Colors.black.withOpacity(0.35), borderRadius: BorderRadius.circular(22), border: Border.all(color: flashEncendido ? const Color(0xFFFFD60A) : Colors.white.withOpacity(0.15), width: 1.2)), child: IconButton(icon: Icon(flashEncendido ? CupertinoIcons.bolt_fill : CupertinoIcons.bolt_slash_fill, color: flashEncendido ? const Color(0xFFFFD60A) : Colors.white70, size: 20), onPressed: _conmutarFlash)))),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 104, left: 0, right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _tomarFoto,
                child: Container(
                  width: 76, height: 76,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: procesandoFoto ? colorVerdeIOS : Colors.white, width: 3.5)), padding: const EdgeInsets.all(4),
                  child: Container(decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white), child: procesandoFoto ? const Center(child: CupertinoActivityIndicator(color: Colors.black, radius: 10)) : null),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 24, left: 20, right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white.withOpacity(0.15), width: 1)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _botonDock('Consulta General', CupertinoIcons.doc_text_search),
                      _botonDock('Perfil Base', CupertinoIcons.person_crop_circle),
                      _botonDock('Perfil Temporal', CupertinoIcons.clock),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonDock(String titulo, IconData icono) {
    final bool esActivo = modoActivo == titulo;
    return GestureDetector(
      onTap: () { if (titulo == 'Consulta General') { setState(() => modoActivo = titulo); } else { _abrirPanelConfiguracion(titulo); } },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: esActivo ? Colors.white.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Icon(icono, size: 16, color: esActivo ? Colors.white : Colors.white54), const SizedBox(width: 6),
            Text(titulo.split(' ').last, style: TextStyle(fontSize: 12, fontWeight: esActivo ? FontWeight.w600 : FontWeight.w400, color: esActivo ? Colors.white : Colors.white54)),
          ],
        ),
      ),
    );
  }
}