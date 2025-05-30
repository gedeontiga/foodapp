class Meal {
  final String name;
  final int calories;
  final String type;
  final List<String> tags;
  final String? image;
  final String? ingredients;
  final String? recipe;

  Meal({
    required this.name,
    required this.calories,
    required this.type,
    required this.tags,
    this.image,
    this.ingredients,
    this.recipe,
  });
}