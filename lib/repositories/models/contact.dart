class Contact {
  String? phoneNumber;
  String? mail;
  String? website;
  String? adress;

  Contact({this.phoneNumber, this.mail, this.website, this.adress});

  Map<String, dynamic> toJson() {
    return {
      'phoneNumber': phoneNumber,
      'mail': mail,
      'website': website,
      'adress': adress,
    };
  }

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      phoneNumber: json['phoneNumber'],
      mail: json['mail'],
      website: json['website'],
      adress: json['adress'],
    );
  }
}

