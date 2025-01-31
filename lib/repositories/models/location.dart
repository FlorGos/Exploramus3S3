import 'package:swipezone/repositories/models/weekly_schedule.dart';
import 'package:swipezone/repositories/models/categories.dart';
import 'package:swipezone/repositories/models/contact.dart';
import 'package:swipezone/repositories/models/localization.dart';

class Location {
  final String nom;
  final String description;
  final WeeklySchedule? schedule;
  final Contact? contact;
  final String imagePath;
  final Categories category;
  final String? website;
  final Localization localization;
  bool isLiked;

  Location({
    required this.nom,
    required this.description,
    this.schedule,
    this.contact,
    required this.imagePath,
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
      'imagePath': imagePath,
      'category': category.toString(),
      'website': website,
      'localization': localization.toJson(),
      'isLiked': isLiked,
    };
  }
  Location clone() {
    return Location(
      nom: this.nom,
      description: this.description,
      schedule: this.schedule,
      contact: this.contact,
      imagePath: this.imagePath,
      category: this.category,
      website: this.website,
      localization: Localization(
        this.localization.adress,
        this.localization.lat,
        this.localization.lng,
      ),
      isLiked: this.isLiked,
    );
  }

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      nom: json['nom'],
      description: json['description'],
      schedule: json['schedule'] != null ? WeeklySchedule.fromJson(json['schedule']) : null,
      contact: json['contact'] != null ? Contact.fromJson(json['contact']) : null,
      imagePath: json['imagePath'],
      category: Categories.values.firstWhere((e) => e.toString() == json['category']),
      website: json['website'],
      localization: Localization.fromJson(json['localization']),
      isLiked: json['isLiked'] ?? false,
    );
  }
}
