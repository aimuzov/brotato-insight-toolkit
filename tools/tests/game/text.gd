extends Node
func get_formatted_number(value,neg=false):
 var digits = str(value)
 var result = "-" if neg else ""
 var remainder = digits.length()%3
 for i in digits.length():
  if i!=0 and i%3==remainder:
   result += ","
  result += digits[i]
 return result
func text(key,args=[],_signs=[]):
 var result = key
 for i in args.size():
  result = result.replace("{"+str(i)+"}",str(args[i]))
 return result
