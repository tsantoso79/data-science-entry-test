def update_dictionary(dct, key, value):
    """
    Task 1
    - Create a function that updates a dictionary (dct) with a new key-value pair.
    - If the key already exists in dct, print the original value, then update its value.
    - Return the updated dictionary.
    """
    if isinstance(dct, dict):
       
        if key in dct:
           print(f"Key '{key}' already exists with value: {dct[key]}")
           dct[key] = value
           print(f"Key '{key}' updated to : {value}")
        else:
            print(f"Key '{key}' added as : {value}")
            dct[key] = value
            
            
    else:   
        print("input is not a dictionary object type")
  
        
    return dct

    return


# Task 2
# Invoke the function "update_dictionary" using the following scenarios:
# - {}, "name", "Alice"
# - {"age": 25}, "age", 26

# Scenarios
dict1 = update_dictionary({}, "name", "Alice")
print(dict1)

dict2 = update_dictionary({"age": 25}, "age", 26)
print(dict2)