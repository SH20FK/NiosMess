/// Inserts into an already ordered, mutable history using logarithmic lookup.
/// Moving the suffix is still linear; the untouched history is never sorted.
void insertSorted<T>(List<T> history, T value, Comparator<T> compare) {
  var lower = 0;
  var upper = history.length;
  while (lower < upper) {
    final middle = lower + ((upper - lower) >> 1);
    if (compare(history[middle], value) <= 0) {
      lower = middle + 1;
    } else {
      upper = middle;
    }
  }
  history.insert(lower, value);
}

/// Linear merge. Both inputs must be ordered and deduplicated by the caller.
List<T> mergeSorted<T>(List<T> left, List<T> right, Comparator<T> compare) {
  final result = <T>[];
  var a = 0;
  var b = 0;
  while (a < left.length && b < right.length) {
    if (compare(left[a], right[b]) <= 0) {
      result.add(left[a++]);
    } else {
      result.add(right[b++]);
    }
  }
  result.addAll(left.skip(a));
  result.addAll(right.skip(b));
  return result;
}
