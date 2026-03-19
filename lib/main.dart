import 'dart:convert';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: 'SpaceX Launches', home: CarouselExample());
  }
}

class RocketImagesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => [];

  Future<void> fetchRocketImages() async {
    final response = await http.get(
      Uri.parse('https://api.spacexdata.com/v4/rockets'),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      final List<String> selectedImages = [];

      for (int i = 0; i < 4 && i < data.length; i++) {
        List<dynamic> images = data[i]['flickr_images'];
        if (images.isNotEmpty) {
          selectedImages.add(images.first);
        }
      }

      state = selectedImages;
    } else {
      throw Exception('Failed to load rocket images');
    }
  }
}

final rocketImagesProvider =
    NotifierProvider<RocketImagesNotifier, List<String>>(
      () => RocketImagesNotifier(),
    );

class CurrentIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    state = index;
  }
}

final currentIndexProvider = NotifierProvider<CurrentIndexNotifier, int>(
  () => CurrentIndexNotifier(),
);

final launchesProvider = FutureProvider.family<List<Launch>, String>((
  ref,
  siteName,
) async {
  final response = await http.get(
    Uri.parse('https://api.spacexdata.com/v3/launches'),
  );
  if (response.statusCode == 200) {
    final List<dynamic> data = jsonDecode(response.body);
    final filtered = data
        .where((json) => json['launch_site']['site_name_long'] == siteName)
        .toList();
    return filtered.map((json) => Launch.fromJson(json)).toList();
  } else {
    throw Exception('Failed to load launches');
  }
});

class CarouselExample extends ConsumerStatefulWidget {
  const CarouselExample({super.key});

  @override
  ConsumerState<CarouselExample> createState() => _CarouselExampleState();
}

class _CarouselExampleState extends ConsumerState<CarouselExample> {
  final Map<int, String> siteMap = {
    0: "Kwajalein Atoll Omelek Island",
    1: "Cape Canaveral Air Force Station Space Launch Complex 40",
    2: "Kennedy Space Center Historic Launch Complex 39A",
    3: "Vandenberg Air Force Base Space Launch Complex 4E",
  };

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(rocketImagesProvider.notifier).fetchRocketImages(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rocketImages = ref.watch(rocketImagesProvider);
    final currentIndex = ref.watch(currentIndexProvider);
    final selectedSite = siteMap[currentIndex]!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'SpaceX Launches',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          rocketImages.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.green),
                )
              : CarouselSlider(
                  items: rocketImages
                      .map(
                        (item) => Container(
                          margin: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: NetworkImage(item),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  options: CarouselOptions(
                    height: 194,
                    autoPlay: false,
                    aspectRatio: 16 / 8,
                    viewportFraction: 0.78,
                    enlargeCenterPage: true,
                    enlargeStrategy: CenterPageEnlargeStrategy.height,
                    onPageChanged: (index, reason) {
                      ref.read(currentIndexProvider.notifier).setIndex(index);
                    },
                  ),
                ),
          const SizedBox(height: 16),
          Expanded(
            child: ref
                .watch(launchesProvider(selectedSite))
                .when(
                  data: (launches) {
                    if (launches.isEmpty) {
                      return const Center(
                        child: Text('No launches for this site.'),
                      );
                    }
                    return ListView.builder(
                      itemCount: launches.length,
                      itemBuilder: (context, index) {
                        final launch = launches[index];
                        final formattedDate = DateFormat(
                          'dd/MM/yyyy',
                        ).format(launch.launchDate);
                        final formattedTime = DateFormat(
                          'h:mm a',
                        ).format(launch.launchDate);
                        return Card(
                          color: const Color.fromRGBO(28, 28, 28, 1),
                          margin: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7),
                          ),
                          elevation: 3,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      formattedDate,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Color.fromRGBO(186, 252, 84, 1),
                                      ),
                                    ),
                                    Text(
                                      formattedTime,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Color.fromRGBO(197, 197, 197, 1),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        launch.missionName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                        ),
                                      ),
                                      Text(
                                        launch.launchSite,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Color.fromRGBO(
                                            197,
                                            197,
                                            197,
                                            1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Colors.green),
                  ),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                ),
          ),
        ],
      ),
    );
  }
}

class Launch {
  final String missionName;
  final DateTime launchDate;
  final String launchSite;

  Launch({
    required this.missionName,
    required this.launchDate,
    required this.launchSite,
  });

  factory Launch.fromJson(Map<String, dynamic> json) {
    return Launch(
      missionName: json['mission_name'],
      launchDate: DateTime.parse(json['launch_date_utc']),
      launchSite: json['launch_site']['site_name_long'],
    );
  }
}
