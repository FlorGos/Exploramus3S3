import 'package:swipezone/repositories/models/weekly_schedule.dart';
import 'package:swipezone/repositories/models/categories.dart';
import 'package:swipezone/repositories/models/contact.dart';
import 'package:swipezone/repositories/models/localization.dart';

class Location {
  final String nom;
  final String description;
  final WeeklySchedule? schedule;
  final Contact? contact;
  String? imageUrl;  // Changé de final à variable
  final Categories category;
  final String? website;
  final Localization localization;
  bool isLiked;

  Location({
    required this.nom,
    required this.description,
    this.schedule,
    this.contact,
    this.imageUrl,
    required this.category,
    this.website,
    required this.localization,
    this.isLiked = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'nom': nom,
      'description': description,
      'schedule': schedule?.toJson(),
      'contact': contact?.toJson(),
      'imageUrl': imageUrl,
      'category': category.toString(),
      'website': website,
      'localization': localization.toJson(),
      'isLiked': isLiked,
    };
  }

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      nom: json['nom'],
      description: json['description'],
      schedule: json['schedule'] != null ? WeeklySchedule.fromJson(json['schedule']) : null,
      contact: json['contact'] != null ? Contact.fromJson(json['contact']) : null,
      imageUrl: json['imageUrl'],
      category: Categories.values.firstWhere((e) => e.toString() == json['category']),
      website: json['website'],
      localization: Localization.fromJson(json['localization']),
      isLiked: json['isLiked'] ?? false,
    );
  }
}

