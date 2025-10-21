import numbers


def find_first_negative(lst):
    """
    Task 1
    - Create a function that finds the first negative number in a list (lst).
    - Return the first negative number if found, otherwise return "No negatives".
    - Use a while loop to implement this.
    """
    i = 0

    while i < len(lst):
        if isinstance(lst[i], numbers.Number):
            if lst[i] < 0:
               print(f" First -ve number found {lst[i]}")
               return lst[i]
        i += 1

    print("No Negatives")

    return None


# Task 2
# Invoke the function "find_first_negative" using the following scenario:
# - [3, 5, -1, 7, -2, 8]
# - [2, 10, 7, 0]

x1 = find_first_negative([3, 5, -1, 7, -2, 8])
print(x1)

x2 = find_first_negative([2, 10, 7, 0])
print(x2)
