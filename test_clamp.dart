void main() {
  try {
    print((-1).clamp(0, 3));
  } catch (e) {
    print("Error: $e");
  }
}
