import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';

// =========================================================================
// 1. KONSTANTA & API KEY
// =========================================================================

// Menggunakan kunci API dan Base URL Weatherbit
const String _apiKey = ' Api';
const String _baseUrl = 'Api';

// =========================================================================
// 2. MODEL DATA (Diperluas untuk mencakup Feels Like, Detail, Hourly, History)
// =========================================================================

class Weather {
  final String cityName;
  final double temperature;
  final double appTemperature; // Suhu terasa seperti (Feels Like)
  final String mainCondition;
  final String description;
  final int humidity;
  final double windSpeed;
  final String windDirectionFull; // Arah Angin
  final double pressure;
  final double uvIndex;
  final double visibility;
  final String sunrise;
  final String sunset;
  final int timestamp;
  final bool hasAlert;
  final String alertTitle;

  Weather({
    required this.cityName,
    required this.temperature,
    required this.appTemperature,
    required this.mainCondition,
    required this.description,
    required this.humidity,
    required this.windSpeed,
    required this.windDirectionFull,
    required this.pressure,
    required this.uvIndex,
    required this.visibility,
    required this.sunrise,
    required this.sunset,
    required this.timestamp,
    this.hasAlert = false,
    this.alertTitle = '',
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    final data = json['data'][0];

    // Asumsi ada data alerts di response Weatherbit (hanya tersedia di plan tertentu)
    final alertsList = json['alerts'] as List<dynamic>?;
    bool hasAlert = (alertsList != null && alertsList.isNotEmpty);
    String alertTitle = hasAlert ? alertsList[0]['title'] as String : '';

    // === START: DUMMY ALERT UNTUK DEMO UI (Hapus ini untuk mode produksi) ===
    // Memastikan komponen Alert terlihat pada load awal di Jakarta.
    if (!hasAlert && data['city_name'] == 'Jakarta') {
      hasAlert = true;
      alertTitle = 'Peringatan Demo: Hujan Lebat Lokal (14:00 - 16:00)';
    }
    // === END: DUMMY ALERT UNTUK DEMO ===

    return Weather(
      cityName: data['city_name'] as String,
      temperature: (data['temp'] as num).toDouble(),
      appTemperature: (data['app_temp'] as num).toDouble(), // Feels Like
      mainCondition:
          (data['weather']['description'] as String).split(' ').first,
      description: data['weather']['description'] as String,
      humidity: data['rh'] as int,
      windSpeed: (data['wind_spd'] as num).toDouble(),
      windDirectionFull: data['wind_cdir_full'] as String,
      pressure: (data['pres'] as num).toDouble(),
      uvIndex: (data['uv'] as num).toDouble(),
      visibility: (data['vis'] as num).toDouble(), // dalam km
      sunrise: data['sunrise'] as String, // Waktu sunrise string "HH:MM"
      sunset: data['sunset'] as String, // Waktu sunset string "HH:MM"
      timestamp: data['ts'] as int,
      hasAlert: hasAlert,
      alertTitle: alertTitle,
    );
  }
}

class ForecastItem {
  final int timestamp;
  final double tempMin;
  final double tempMax;
  final double appTempMax; // Suhu terasa maksimum
  final String mainCondition;
  final String description;

  ForecastItem({
    required this.timestamp,
    required this.tempMin,
    required this.tempMax,
    required this.appTempMax,
    required this.mainCondition,
    required this.description,
  });

  factory ForecastItem.fromDailyJson(Map<String, dynamic> json) {
    return ForecastItem(
      timestamp: json['ts'] as int,
      tempMin: (json['min_temp'] as num).toDouble(),
      tempMax: (json['max_temp'] as num).toDouble(),
      appTempMax: (json['app_max_temp'] as num).toDouble(),
      mainCondition:
          (json['weather']['description'] as String).split(' ').first,
      description: json['weather']['description'] as String,
    );
  }
}

class HourlyForecastItem {
  final int timestamp;
  final double temperature;
  final String mainCondition;

  HourlyForecastItem({
    required this.timestamp,
    required this.temperature,
    required this.mainCondition,
  });

  factory HourlyForecastItem.fromJson(Map<String, dynamic> json) {
    return HourlyForecastItem(
      timestamp: json['ts'] as int,
      temperature: (json['temp'] as num).toDouble(),
      mainCondition:
          (json['weather']['description'] as String).split(' ').first,
    );
  }
}

class HistorySummary {
  final double tempMin;
  final double tempMax;
  final String mainCondition;
  final String description;

  HistorySummary({
    required this.tempMin,
    required this.tempMax,
    required this.mainCondition,
    required this.description,
  });

  factory HistorySummary.fromJson(Map<String, dynamic> json) {
    final data = json['data']
        [0]; // Ambil data hari kemarin (sudah dijamin non-null oleh pemanggil)
    return HistorySummary(
      tempMin: (data['min_temp'] as num).toDouble(),
      tempMax: (data['max_temp'] as num).toDouble(),
      mainCondition:
          (data['weather']['description'] as String).split(' ').first,
      description: data['weather']['description'] as String,
    );
  }
}

// =========================================================================
// 3. HELPER FUNCTIONS (Warna, Icon, Mood/Tips, Date Formatting)
// =========================================================================

// Mengambil warna/gradient latar belakang berdasarkan kondisi cuaca
List<Color> getWeatherColor(String condition, bool isDayTime) {
  if (!isDayTime) {
    return [const Color(0xFF152A4E), const Color(0xFF2E4064)]; // Malam/Gelap
  }
  switch (condition.toLowerCase()) {
    case 'clear':
    case 'sun':
      return [
        const Color(0xFF4FC3F7),
        const Color(0xFF81D4FA)
      ]; // Biru Langit Cerah
    case 'clouds':
    case 'cloudy':
    case 'mist':
    case 'fog':
    case 'haze':
      return [
        const Color(0xFF90A4AE),
        const Color(0xFFB0BEC5)
      ]; // Abu-abu Mendung
    case 'rain':
    case 'drizzle':
    case 'shower':
    case 'thunderstorm':
      return [
        const Color(0xFF546E7A),
        const Color(0xFF78909C)
      ]; // Biru Slate (Hujan)
    case 'snow':
    case 'sleet':
      return [const Color(0xFFCFD8DC), const Color(0xFFECEFF1)]; // Putih Salju
    default:
      return [
        const Color(0xFF4DB6AC),
        const Color(0xFF80CBC4)
      ]; // Default Hijau Tosca
  }
}

// Mengambil ikon Material berdasarkan kondisi cuaca
IconData getWeatherIcon(String condition) {
  switch (condition.toLowerCase()) {
    case 'clear':
    case 'sun':
      return Icons.wb_sunny;
    case 'clouds':
    case 'cloudy':
      return Icons.cloud;
    case 'rain':
    case 'drizzle':
    case 'shower':
      return Icons.water_drop;
    case 'thunderstorm':
      return Icons.flash_on;
    case 'snow':
    case 'sleet':
      return Icons.ac_unit;
    case 'mist':
    case 'fog':
    case 'haze':
      return Icons.blur_on;
    default:
      return Icons.cloud_queue;
  }
}

// Memberikan mood atau tips berdasarkan kondisi cuaca
Map<String, String> getMoodAndTip(String condition) {
  switch (condition.toLowerCase()) {
    case 'clear':
    case 'sun':
      return {
        'mood': 'Cerah & Semangat!',
        'tip':
            'Hari terbaik untuk aktivitas luar ruangan! Jangan lupa tabir surya dan hidrasi.',
      };
    case 'clouds':
    case 'cloudy':
      return {
        'mood': 'Santai & Tenang.',
        'tip':
            'Manfaatkan suasana sejuk untuk fokus bekerja atau eksplorasi kota tanpa terlalu panas.',
      };
    case 'rain':
    case 'drizzle':
    case 'shower':
      return {
        'mood': 'Nyaman & Produktif.',
        'tip':
            'Minum hangat dan gunakan waktu ini untuk perencanaan mendalam. Hati-hati di jalan!',
      };
    case 'snow':
    case 'sleet':
      return {
        'mood': 'Magis & Hangat.',
        'tip':
            'Kenakan lapisan tebal dan nikmati pemandangan. Hati-hati dengan permukaan yang licin.',
      };
    default:
      return {
        'mood': 'Siap untuk Segala Hal.',
        'tip':
            'Selalu bawa payung. Ini hari yang baik untuk merenung dan fokus pada detail.',
      };
  }
}

// Helper Class untuk format tanggal
class DateFormat {
  final DateTime date;
  DateFormat(this.date);

  static const List<String> _days = [
    'Min',
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab'
  ];

  String format(String pattern) {
    if (pattern == 'EEE') {
      final int index = date.weekday % 7;
      return _days[index];
    }
    return date.toString();
  }
}

// =========================================================================
// 4. MAIN WIDGET
// =========================================================================

void main() {
  runApp(const WeatherMoodApp());
}

class WeatherMoodApp extends StatelessWidget {
  const WeatherMoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather+Mood App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Inter',
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      home: const WeatherHomePage(),
    );
  }
}

// =========================================================================
// 5. HALAMAN UTAMA (STATEFUL WIDGET)
// =========================================================================

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key});

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  final TextEditingController _cityController = TextEditingController();
  Weather? _weatherData;
  List<ForecastItem> _dailyForecast = [];
  List<HourlyForecastItem> _hourlyForecast = [];
  HistorySummary? _historySummary;
  bool _isLoading = false;
  String? _errorMessage;
  String _currentCity = 'Jakarta';
  bool _isDayTime = true; // State untuk mode siang/malam

  @override
  void initState() {
    super.initState();
    _fetchWeatherData(_currentCity);
  }

  // Fungsi utama untuk mengambil semua data cuaca
  Future<void> _fetchWeatherData(String city) async {
    if (city.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentCity = city;
    });

    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayString =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      // 1. Current Weather & Alerts
      final weatherResponse = await http.get(Uri.parse(
          '$_baseUrl/current?city=$city&key=$_apiKey&units=M&lang=id&alerts=live'));

      // 2. Daily Forecast (4 hari)
      final dailyResponse = await http.get(Uri.parse(
          '$_baseUrl/forecast/daily?city=$city&key=$_apiKey&days=4&units=M&lang=id'));

      // 3. Hourly Forecast (24 jam)
      final hourlyResponse = await http.get(Uri.parse(
          '$_baseUrl/forecast/hourly?city=$city&key=$_apiKey&hours=24&units=M&lang=id'));

      // 4. Yesterday Summary (History)
      final historyResponse = await http.get(Uri.parse(
          '$_baseUrl/history/daily?city=$city&key=$_apiKey&units=M&lang=id&start_date=$yesterdayString&end_date=$yesterdayString'));

      if (weatherResponse.statusCode == 200 &&
          dailyResponse.statusCode == 200 &&
          hourlyResponse.statusCode == 200 &&
          historyResponse.statusCode == 200) {
        final weatherJson = jsonDecode(weatherResponse.body);
        final dailyJson = jsonDecode(dailyResponse.body);
        final hourlyJson = jsonDecode(hourlyResponse.body);
        final historyJson = jsonDecode(historyResponse.body);

        final current = Weather.fromJson(weatherJson);

        List<ForecastItem> tempDaily = [];
        final List<dynamic> dailyList = dailyJson['data'];
        for (int i = 1; i < dailyList.length; i++) {
          tempDaily.add(ForecastItem.fromDailyJson(dailyList[i]));
        }

        List<HourlyForecastItem> tempHourly = (hourlyJson['data'] as List)
            .take(24)
            .map((e) => HourlyForecastItem.fromJson(e))
            .toList();

        // Safety check untuk History Summary (agar tidak crash jika data kosong)
        HistorySummary? history;
        if (historyJson['data'] != null && historyJson['data'].isNotEmpty) {
          history = HistorySummary.fromJson(historyJson);
        } else {
          print('History data for yesterday is empty.');
        }

        // Tentukan mode siang/malam berdasarkan waktu sunrise/sunset
        _isDayTime = _checkIsDayTime(current.sunrise, current.sunset);

        setState(() {
          _weatherData = current;
          _dailyForecast = tempDaily;
          _hourlyForecast = tempHourly;
          _historySummary = history;
          _errorMessage = null;
        });
      } else {
        // Handle error jika salah satu API call gagal
        setState(() {
          _errorMessage = 'Gagal memuat data. Periksa kota atau kunci API.';
          _weatherData = null;
          _dailyForecast = [];
          _hourlyForecast = [];
          _historySummary = null;
        });
      }
    } catch (e) {
      print('Error fetching data: $e');
      setState(() {
        _errorMessage =
            'Terjadi kesalahan jaringan atau server. Coba lagi. (Pastikan Kunci API valid)';
        _weatherData = null;
        _dailyForecast = [];
        _hourlyForecast = [];
        _historySummary = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper untuk menentukan apakah sekarang siang atau malam
  bool _checkIsDayTime(String sunriseStr, String sunsetStr) {
    try {
      final now = DateTime.now();
      // Hanya ambil jam dan menit
      final sunriseParts = sunriseStr.split(':').map(int.parse).toList();
      final sunsetParts = sunsetStr.split(':').map(int.parse).toList();

      final sunrise = DateTime(
          now.year, now.month, now.day, sunriseParts[0], sunriseParts[1]);
      final sunset = DateTime(
          now.year, now.month, now.day, sunsetParts[0], sunsetParts[1]);

      return now.isAfter(sunrise) && now.isBefore(sunset);
    } catch (_) {
      return true; // Default ke siang jika gagal parsing
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentCondition = _weatherData?.mainCondition ?? 'Clear';
    final List<Color> backgroundColors =
        getWeatherColor(currentCondition, _isDayTime);

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 1200),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: backgroundColors,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSearchInput(),
                const SizedBox(height: 20),
                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _cityController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Cari kota...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30.0),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
            onSubmitted: (value) => _fetchWeatherData(value),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(30.0),
          ),
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(15.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.search, color: Colors.white, size: 28),
                  onPressed: () {
                    _fetchWeatherData(_cityController.text);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading && _weatherData == null) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    if (_errorMessage != null) {
      return Center(
        child: Text('Error: $_errorMessage',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18)),
      );
    }
    if (_weatherData == null) {
      return Center(
        child: Text(
            'Masukkan nama kota untuk melihat prakiraan cuaca yang rinci.',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 18)),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWeatherAlerts(), // Alert
          _buildCurrentWeather(), // Kota, Suhu, Icon
          _buildSunriseSunset(), // Sunrise & Sunset
          const SizedBox(height: 30),
          _buildDetailsGrid(), // Detail Cuaca (Angin, UV, Tekanan, dll)
          const SizedBox(height: 30),
          _buildHourlyChart(), // Grafik Suhu Per Jam
          const SizedBox(height: 30),
          _buildForecastTitle('Prakiraan 3 Hari'),
          const SizedBox(height: 15),
          _buildDailyForecastList(), // Forecast 3 Hari
          const SizedBox(height: 30),
          _buildYesterdaySummary(), // Cuaca Kemarin
          const SizedBox(height: 30),
          _buildMoodPanel(), // Mood Harian & Tips
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // Komponen 5: Alert / Peringatan Cuaca
  Widget _buildWeatherAlerts() {
    if (_weatherData!.hasAlert) {
      return Container(
        padding: const EdgeInsets.all(15),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.white, size: 30),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PERINGATAN CUACA EKSTREM',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(_weatherData!.alertTitle,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // Komponen 1: Tampilan Cuaca Utama
  Widget _buildCurrentWeather() {
    final w = _weatherData!;
    return Column(
      children: [
        // Nama Kota
        Text(
          w.cityName,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            shadows: [Shadow(blurRadius: 10, color: Colors.black26)],
          ),
        ),
        // Icon & Suhu
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Cuaca
            Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: Icon(
                getWeatherIcon(w.mainCondition),
                color: Colors.white,
                size: 80,
              ),
            ),
            // Temperatur
            Text(
              '${w.temperature.round()}',
              style: const TextStyle(
                fontSize: 100,
                fontWeight: FontWeight.w100,
                color: Colors.white,
                height: 1.0,
                shadows: [Shadow(blurRadius: 10, color: Colors.black26)],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 15),
              child: Text('°C',
                  style: TextStyle(
                      fontSize: 30,
                      color: Colors.white,
                      fontWeight: FontWeight.w400)),
            ),
          ],
        ),
        // Deskripsi Cuaca
        Text(
          w.description,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        // Feels Like
        Text(
          'Terasa seperti: ${w.appTemperature.round()}°C',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  // Komponen 1 & 7 (Opsional): Sunrise & Sunset
  Widget _buildSunriseSunset() {
    final w = _weatherData!;
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSunTime(Icons.wb_sunny, 'Sunrise', w.sunrise),
          Container(height: 30, width: 1, color: Colors.white54),
          _buildSunTime(Icons.wb_twilight, 'Sunset', w.sunset),
        ],
      ),
    );
  }

  Widget _buildSunTime(IconData icon, String title, String time) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 4),
        Text(time,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  // Komponen 1: Detail Cuaca dalam Grid
  Widget _buildDetailsGrid() {
    final w = _weatherData!;
    final List<Map<String, dynamic>> details = [
      {
        'icon': Icons.water_drop,
        'title': 'Kelembapan',
        'value': '${w.humidity}%'
      },
      {
        'icon': Icons.air,
        'title': 'Kecepatan Angin',
        'value': '${w.windSpeed.toStringAsFixed(1)} m/s'
      },
      {
        'icon': Icons.explore,
        'title': 'Arah Angin',
        'value': w.windDirectionFull
      },
      {
        'icon': Icons.thermostat_outlined,
        'title': 'Tekanan',
        'value': '${w.pressure.round()} mb'
      },
      {
        'icon': Icons.wb_incandescent,
        'title': 'UV Index',
        'value': w.uvIndex.toStringAsFixed(1)
      },
      {
        'icon': Icons.visibility,
        'title': 'Visibilitas',
        'value': '${w.visibility.round()} km'
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 2.2, // Kontrol tinggi item
      ),
      itemCount: details.length,
      itemBuilder: (context, index) {
        final detail = details[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Icon(detail['icon'] as IconData, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(detail['title'] as String,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(detail['value'] as String,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Komponen 4: Grafik Suhu Per Jam (Custom Painter)
  Widget _buildHourlyChart() {
    if (_hourlyForecast.isEmpty) return const SizedBox.shrink();

    // Dapatkan data suhu dan cari min/max untuk skala
    final temperatures = _hourlyForecast.map((e) => e.temperature).toList();
    final minTemp = temperatures.reduce(min) - 2;
    final maxTemp = temperatures.reduce(max) + 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildForecastTitle('Prakiraan Per Jam (24 Jam)'),
        const SizedBox(height: 15),
        Container(
          height: 220, // Ketinggian grafik
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _hourlyForecast.length,
            itemBuilder: (context, index) {
              final item = _hourlyForecast[index];
              final time =
                  DateTime.fromMillisecondsSinceEpoch(item.timestamp * 1000);

              // Hitung posisi vertikal (untuk visualisasi)
              // Normalisasi suhu agar nilai visualnya antara 0 dan 1.
              // Jika minTemp dan maxTemp sama, gunakan nilai default (misal 0.5)
              double normalizedTemp = 0.5;
              if (maxTemp != minTemp) {
                normalizedTemp =
                    (item.temperature - minTemp) / (maxTemp - minTemp);
              }

              return Container(
                width: 70,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Waktu
                    Text('${time.hour.toString().padLeft(2, '0')}:00',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),

                    // Icon Cuaca
                    Icon(getWeatherIcon(item.mainCondition),
                        color: Colors.white, size: 30),

                    // Suhu (besar)
                    Text(
                      '${item.temperature.round()}°C',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),

                    // Indikator visual (placeholder untuk grafik)
                    Container(
                      height: 50 * normalizedTemp,
                      width: 4,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.white.withOpacity(0.5),
                              blurRadius: 3)
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Komponen 3: Cuaca Kemarin
  Widget _buildYesterdaySummary() {
    if (_historySummary == null) return const SizedBox.shrink();
    final h = _historySummary!;

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white.withOpacity(0.2),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildForecastTitle('Ringkasan Cuaca Kemarin'),
            const Divider(color: Colors.white54, height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h.description,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      Text(
                          'Max: ${h.tempMax.round()}°C | Min: ${h.tempMin.round()}°C',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
                Icon(getWeatherIcon(h.mainCondition),
                    color: Colors.white, size: 50),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Komponen 2: Mood Panel
  Widget _buildMoodPanel() {
    final w = _weatherData!;
    final moodData = getMoodAndTip(w.mainCondition);

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white.withOpacity(0.2),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite_border,
                    color: Colors.white, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mood Harian: ${moodData['mood']}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white70, height: 25),
            Text(
              moodData['tip']!,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForecastTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          shadows: [Shadow(blurRadius: 5, color: Colors.black26)],
        ),
      ),
    );
  }

  // Komponen 3: Forecast 3 Hari (Horizontal List)
  Widget _buildDailyForecastList() {
    if (_dailyForecast.isEmpty) {
      return const Text(
        'Tidak ada data prakiraan 3 hari tersedia.',
        style: TextStyle(color: Colors.white70),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _dailyForecast.length,
        itemBuilder: (context, index) {
          final item = _dailyForecast[index];
          return _buildForecastCard(item);
        },
      ),
    );
  }

  Widget _buildForecastCard(ForecastItem item) {
    final day = DateTime.fromMillisecondsSinceEpoch(item.timestamp * 1000);
    final dayName = DateFormat(day).format('EEE');
    final itemColors = getWeatherColor(
        item.mainCondition, true); // Selalu anggap siang untuk kartu forecast

    return Card(
      elevation: 5,
      margin: const EdgeInsets.only(right: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: itemColors.map((c) => c.withOpacity(0.9)).toList(),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Nama Hari
            Text(
              dayName,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18),
            ),

            // Icon
            Icon(getWeatherIcon(item.mainCondition),
                color: Colors.white, size: 45),

            // Suhu Min/Max
            Text(
              '${item.tempMax.round()}° / ${item.tempMin.round()}°',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16),
            ),

            // Suhu Terasa
            Text(
              'Terasa: ${item.appTempMax.round()}°',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),

            // Deskripsi Singkat
            Text(
              item.description,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w300),
            ),
          ],
        ),
      ),
    );
  }
}
