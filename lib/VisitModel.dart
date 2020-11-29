import 'dart:convert';

Visit visitFromJson(String str) {
  final jsonData = json.decode(str);
  return Visit.fromMap(jsonData);
}

String visitToJson(Visit data) {
  final dyn = data.toMap();
  return json.encode(dyn);
}

class Visit {
  int id;
  String city;
  int count;

  Visit({
    this.id,
    this.city,
    this.count
  });

  factory Visit.fromMap(Map<String, dynamic> json) => new Visit(
    id: json["id"],
    city: json["city"],
    count: json["count"],
  );

  Map<String, dynamic> toMap() => {
    "id": id,
    "city": city,
    "count": count,
  };
}