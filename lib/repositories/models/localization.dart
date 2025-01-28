class Localization {
  String? adress;
  double? lat;
  double? lng;

  Localization(this.adress, this.lat, this.lng);

  Map<String, dynamic> toJson() {
    return {
      'adress': adress,
      'lat': lat,
      'lng': lng,
    };
  }

  factory Localization.fromJson(Map<String, dynamic> json) {
    return Localization(
      json['adress'],
      json['lat'],
      json['lng'],
    );
  }
}

