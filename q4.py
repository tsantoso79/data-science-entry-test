def string_reverse(s):
    """
    Task 1
    - Create a function that reverses a given string (s).
    - s must be a string.
    - Return the reversed string.
    """
    if not isinstance(s, str):
        print("Input is not a string type")
        return None

    # Reverse the string using slicing
    reversed_s = s[::-1]

    return reversed_s


# Task 2
# Invoke the function "string_reverse" using the following scenarios:
# - "Hello World"
# - "Python"

result1 = string_reverse("Hello World")
print(result1)

result2 = string_reverse("Python")
print(result2)