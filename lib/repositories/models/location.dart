import 'package:swipezone/repositories/models/weekly_schedule.dart';
import 'activities.dart';
import 'categories.dart';
import 'contact.dart';
import 'localization.dart';

class Location {
  String nom;
  String? description;
  WeeklySchedule? schedule;
  Contact? contact;
  String? photoUrl;
  Categories category;
  List<Activities>? activities;
  Localization localization;
  bool isLiked = false;

  Location(this.nom, this.description, this.schedule, this.contact,
      this.photoUrl, this.category, this.activities, this.localization);

  Map<String, dynamic> toJson() {
    return {
      'nom': nom,
      'description': description,
      'schedule': schedule?.toJson(),
      'contact': contact?.toJson(),
      'photoUrl': photoUrl,
      'category': category.toString(),
      'activities': activities?.map((a) => a.toString()).toList(),
      'localization': localization.toJson(),
      'isLiked': isLiked,
    };
  }

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      json['nom'],
      json['description'],
      json['schedule'] != null ? WeeklySchedule.fromJson(json['schedule']) : null,
      json['contact'] != null ? Contact.fromJson(json['contact']) : null,
      json['photoUrl'],
      Categories.values.firstWhere((e) => e.toString() == json['category']),
      json['activities']?.map((a) => Activities.values.firstWhere((e) => e.toString() == a)).toList().cast<Activities>(),
      Localization.fromJson(json['localization']),
    )..isLiked = json['isLiked'] ?? false;
  }
}

