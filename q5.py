def check_divisibility(num, divisor):
    """
    Task 1
    - Create a function to check if the number (num) is divisible by another number (divisor).
    - Both num and divisor must be numeric.
    - Return True if num is divisible by divisor, False otherwise.
    """
    # Check that both inputs are numeric (int or float)
    if not (isinstance(num, (int, float)) and isinstance(divisor, (int, float)) and abs(divisor) > 0):
        print("Inputs must be numeric and  not zero")
        return None


    # Check divisibility using modulus operator
    if num % divisor == 0:
        return True
    else:
        return False


# Task 2
# Invoke the function "check_divisibility" using the following scenarios:
# - 10, 2
# - 7, 3


result1 = check_divisibility(10, 2)
print(result1)  # Expected: True

result2 = check_divisibility(7, 3)
print(result2)  # Expected: False