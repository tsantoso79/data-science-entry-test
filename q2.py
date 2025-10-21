def find_and_replace(lst, find_val, replace_val):
    """
    Task 1
    - Create a function that searches for all occurrences of a value (find_val) in a given list (lst) and replaces them with another value (replace_val).
    - lst must be a list.
    - Return the modified list.
    """
    if isinstance(lst, list):
       
        for x in range(len(lst)):
         if lst[x] == find_val:
            lst[x] = replace_val
            print(f"{lst[x]} swapped in index", x)
    else:   
        print("input is not a list object type")
  
        
    return lst


# Task 2
# Invoke the function "find_and_replace" using the following scenarios:
# - [1, 2, 3, 4, 2, 2], 2, 5
# - ["apple", "banana", "apple"], "apple", "orange"

# Sceneario 1
new_list_1 = find_and_replace([1, 2, 3, 4, 2, 2], 2, 5)

# Sceneario 2

t = ["apple", "banana", "apple"]
new_list_2 = find_and_replace(["apple", "banana", "apple"], "apple", "orange")