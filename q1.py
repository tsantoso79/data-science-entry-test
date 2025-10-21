import numbers



def swap(x, y):
    """
    Task 1
    - Create a function that would swap the value of x and y using only x and y as variables.
    - x and y must be numeric.
    - Return -1 if x and y is not numeric, and
    - print the swapped values if both x and y are numeric.
    """

    if isinstance(x, numbers.Number) and isinstance(y, numbers.Number):
       x,y = y,x
       print("Swapped values X is ",x," and Y is ",y)
       
    else:
       print(-1)
       
    return    



# Task 2
# Invoke the function "swap" using the following scenarios:
# - "Apple", 10
# - 9, 17

# Sceneario 1
swap("Apple", 10)

# Sceneario 2
swap(9, 17)