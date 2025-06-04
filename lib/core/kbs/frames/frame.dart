// lib/core/kbs/frames/frame.dart

/// Abstract base class for a Frame in the Knowledge-Based System's Working Memory.
/// A Frame represents a structured piece of knowledge.
abstract class Frame {
  /// A unique identifier or type name for the frame.
  String get frameType;

  /// The core data storage of the frame. Rules read from and write to slots.
  // ignore: unintended_html_in_doc_comment
  /// Using Map<String, dynamic> provides flexibility but requires careful type handling.
  Map<String, dynamic> get slots;

  // Optional: Method to update slots, could enforce structure if needed
  void updateSlot(String name, dynamic value) {
    slots[name] = value;
  }

  // Optional: Method to read slots, could add type safety
  // T? readSlot<T>(String name) {
  //   return slots[name] as T?;
  // }
}
