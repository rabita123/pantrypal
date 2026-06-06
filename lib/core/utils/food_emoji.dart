import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';

/// Returns the most specific emoji for a food item by name,
/// falling back to the category emoji when no match is found.
String foodEmoji(String name, FoodCategory fallback) {
  final n = name.toLowerCase().trim();

  // Dish-level patterns (checked first so "Banana Oat Porridge" → 🥣 not 🍌)
  if (_has(n, ['porridge', 'oatmeal'])) return '🥣';
  if (_has(n, ['pancake', 'crepe'])) return '🥞';
  if (_has(n, ['waffle'])) return '🧇';
  if (_has(n, ['sandwich', 'toastie', 'sub', 'blt'])) return '🥪';
  if (_has(n, ['burger', 'hamburger'])) return '🍔';
  if (_has(n, ['pizza'])) return '🍕';
  if (_has(n, ['taco', 'burrito', 'quesadilla'])) return '🌮';
  if (_has(n, ['curry', 'masala', 'korma', 'tikka'])) return '🍛';
  if (_has(n, ['soup', 'stew', 'broth', 'chowder', 'chili'])) return '🍲';
  if (_has(n, ['salad'])) return '🥗';
  if (_has(n, ['nugget', 'nuggets'])) return '🍗';
  if (_has(n, ['fried rice', 'egg fried'])) return '🍚';
  if (_has(n, ['sushi', 'maki', 'onigiri'])) return '🍱';
  if (_has(n, ['noodle soup', 'ramen', 'pho', 'udon'])) return '🍜';
  if (_has(n, ['scrambled egg', 'fried egg', 'omelette', 'omelet', 'frittata'])) return '🍳';
  if (_has(n, ['mac and cheese', 'macaroni'])) return '🧀';
  if (_has(n, ['smoothie', 'milkshake'])) return '🥤';
  if (_has(n, ['french toast'])) return '🍞';

  // Grains & Bread
  if (_has(n, ['rice', 'basmati', 'jasmine rice', 'fried rice'])) return '🍚';
  if (_has(n, ['pasta', 'spaghetti', 'noodle', 'penne', 'fettuccine', 'lasagne', 'lasagna', 'linguine', 'tagliatelle', 'macaroni'])) return '🍝';
  if (_has(n, ['bread', 'baguette', 'toast', 'bagel', 'roll', 'bun', 'loaf', 'sourdough', 'brioche', 'pitta', 'pita', 'tortilla', 'wrap', 'naan'])) return '🍞';
  if (_has(n, ['cereal', 'granola', 'muesli'])) return '🥣';
  if (_has(n, ['oat', 'porridge'])) return '🌾';
  if (_has(n, ['flour', 'wheat', 'grain'])) return '🌾';
  if (_has(n, ['cracker', 'crisp bread'])) return '🍘';
  if (_has(n, ['pretzel'])) return '🥨';
  if (_has(n, ['waffle'])) return '🧇';
  if (_has(n, ['pancake'])) return '🥞';
  if (_has(n, ['croissant'])) return '🥐';
  if (_has(n, ['corn', 'sweetcorn', 'popcorn corn'])) return '🌽';

  // Dairy
  if (_has(n, ['milk', 'semi-skimmed', 'skimmed', 'whole milk', 'oat milk', 'almond milk', 'soy milk'])) return '🥛';
  if (_has(n, ['cheese', 'cheddar', 'mozzarella', 'parmesan', 'brie', 'feta', 'gouda', 'ricotta', 'cottage cheese'])) return '🧀';
  if (_has(n, ['butter', 'margarine'])) return '🧈';
  if (_has(n, ['yogurt', 'yoghurt'])) return '🥛';
  if (_has(n, ['cream', 'custard'])) return '🍶';
  if (_has(n, ['ice cream', 'gelato', 'sorbet'])) return '🍦';

  // Eggs
  if (_has(n, ['egg'])) return '🥚';

  // Meat & Fish
  if (_has(n, ['chicken', 'poultry', 'hen'])) return '🍗';
  if (_has(n, ['turkey'])) return '🦃';
  if (_has(n, ['bacon'])) return '🥓';
  if (_has(n, ['sausage', 'hot dog', 'hotdog', 'frankfurter', 'chorizo', 'salami', 'pepperoni'])) return '🌭';
  if (_has(n, ['ham', 'prosciutto', 'pancetta'])) return '🍖';
  if (_has(n, ['pork', 'ribs', 'chop'])) return '🍖';
  if (_has(n, ['lamb', 'mutton'])) return '🍖';
  if (_has(n, ['beef', 'steak', 'mince', 'ground beef', 'burger'])) return '🥩';
  if (_has(n, ['salmon'])) return '🐟';
  if (_has(n, ['tuna', 'canned tuna', 'tinned tuna'])) return '🥫';
  if (_has(n, ['shrimp', 'prawn'])) return '🍤';
  if (_has(n, ['crab', 'lobster', 'mussel', 'clam', 'oyster', 'squid', 'octopus'])) return '🦞';
  if (_has(n, ['fish', 'cod', 'haddock', 'tilapia', 'sardine', 'mackerel', 'herring', 'trout', 'sea bass'])) return '🐟';

  // Fruits
  if (_has(n, ['apple', 'granny smith', 'fuji'])) return '🍎';
  if (_has(n, ['banana'])) return '🍌';
  if (_has(n, ['orange', 'mandarin', 'clementine', 'tangerine', 'satsuma'])) return '🍊';
  if (_has(n, ['lemon'])) return '🍋';
  if (_has(n, ['lime'])) return '🍋';
  if (_has(n, ['grape'])) return '🍇';
  if (_has(n, ['strawberry'])) return '🍓';
  if (_has(n, ['raspberry', 'blackberry'])) return '🍓';
  if (_has(n, ['blueberry'])) return '🫐';
  if (_has(n, ['mango'])) return '🥭';
  if (_has(n, ['avocado'])) return '🥑';
  if (_has(n, ['watermelon', 'melon'])) return '🍉';
  if (_has(n, ['peach', 'nectarine', 'apricot'])) return '🍑';
  if (_has(n, ['pear'])) return '🍐';
  if (_has(n, ['cherry'])) return '🍒';
  if (_has(n, ['pineapple'])) return '🍍';
  if (_has(n, ['coconut'])) return '🥥';
  if (_has(n, ['kiwi'])) return '🥝';
  if (_has(n, ['pomegranate'])) return '🍎';
  if (_has(n, ['fig', 'date', 'plum'])) return '🍇';

  // Vegetables
  if (_has(n, ['tomato', 'cherry tomato', 'roma', 'plum tomato'])) return '🍅';
  if (_has(n, ['carrot'])) return '🥕';
  if (_has(n, ['broccoli'])) return '🥦';
  if (_has(n, ['spinach', 'kale', 'chard', 'rocket', 'arugula', 'watercress'])) return '🥬';
  if (_has(n, ['lettuce', 'cabbage', 'bok choy', 'pak choi'])) return '🥬';
  if (_has(n, ['potato', 'sweet potato', 'yam'])) return '🥔';
  if (_has(n, ['onion', 'shallot', 'spring onion', 'scallion', 'leek', 'chive'])) return '🧅';
  if (_has(n, ['garlic'])) return '🧄';
  if (_has(n, ['mushroom', 'shiitake', 'portobello', 'oyster mushroom'])) return '🍄';
  if (_has(n, ['pepper', 'capsicum', 'bell pepper', 'chilli', 'jalapeño'])) return '🫑';
  if (_has(n, ['cucumber', 'courgette', 'zucchini', 'gherkin'])) return '🥒';
  if (_has(n, ['aubergine', 'eggplant'])) return '🍆';
  if (_has(n, ['pumpkin', 'squash', 'butternut'])) return '🎃';
  if (_has(n, ['peas', 'green bean', 'french bean', 'edamame', 'sugar snap'])) return '🫛';
  if (_has(n, ['bean', 'kidney bean', 'chickpea', 'lentil', 'lentils', 'black bean'])) return '🫘';
  if (_has(n, ['asparagus'])) return '🫛';
  if (_has(n, ['celery'])) return '🥬';
  if (_has(n, ['beetroot', 'beet'])) return '🍠';
  if (_has(n, ['radish', 'turnip', 'parsnip'])) return '🥕';
  if (_has(n, ['artichoke'])) return '🥦';

  // Beverages
  if (_has(n, ['coffee', 'espresso', 'latte', 'cappuccino', 'americano'])) return '☕';
  if (_has(n, ['tea', 'green tea', 'herbal tea', 'chai'])) return '🍵';
  if (_has(n, ['orange juice', 'apple juice', 'juice'])) return '🧃';
  if (_has(n, ['water', 'sparkling water', 'mineral water'])) return '💧';
  if (_has(n, ['beer', 'ale', 'lager', 'stout'])) return '🍺';
  if (_has(n, ['wine', 'prosecco', 'champagne'])) return '🍷';
  if (_has(n, ['soda', 'cola', 'lemonade', 'fizzy'])) return '🥤';
  if (_has(n, ['smoothie'])) return '🥤';
  if (_has(n, ['milk shake', 'milkshake'])) return '🥤';

  // Snacks & Sweets
  if (_has(n, ['chocolate', 'brownie'])) return '🍫';
  if (_has(n, ['cookie', 'biscuit', 'digestive', 'oreo'])) return '🍪';
  if (_has(n, ['cake', 'muffin', 'cupcake'])) return '🍰';
  if (_has(n, ['donut', 'doughnut'])) return '🍩';
  if (_has(n, ['candy', 'sweet', 'lolly', 'gummy', 'haribo'])) return '🍬';
  if (_has(n, ['popcorn'])) return '🍿';
  if (_has(n, ['chips', 'crisps', 'pringles'])) return '🥔';
  if (_has(n, ['nut', 'almond', 'walnut', 'cashew', 'pecan', 'pistachio', 'hazelnut'])) return '🥜';
  if (_has(n, ['peanut'])) return '🥜';
  if (_has(n, ['granola bar', 'protein bar', 'cereal bar'])) return '🍫';

  // Condiments & Pantry
  if (_has(n, ['salt', 'sea salt', 'rock salt'])) return '🧂';
  if (_has(n, ['honey'])) return '🍯';
  if (_has(n, ['peanut butter', 'almond butter', 'nut butter'])) return '🥜';
  if (_has(n, ['jam', 'jelly', 'marmalade', 'preserve'])) return '🍓';
  if (_has(n, ['ketchup', 'tomato sauce', 'tomato ketchup'])) return '🍅';
  if (_has(n, ['mayonnaise', 'mayo', 'aioli'])) return '🫙';
  if (_has(n, ['mustard'])) return '🟡';
  if (_has(n, ['oil', 'olive oil', 'vegetable oil', 'coconut oil', 'sunflower oil'])) return '🫙';
  if (_has(n, ['vinegar', 'balsamic'])) return '🫙';
  if (_has(n, ['soy sauce', 'worcestershire', 'hot sauce', 'tabasco', 'sriracha', 'sauce'])) return '🫙';
  if (_has(n, ['sugar', 'brown sugar', 'icing sugar', 'caster sugar', 'maple syrup', 'syrup'])) return '🍬';
  if (_has(n, ['canned', 'tinned', 'can of'])) return '🥫';
  if (_has(n, ['stock', 'broth', 'bouillon'])) return '🫙';
  if (_has(n, ['yeast', 'baking powder', 'baking soda'])) return '🧂';
  if (_has(n, ['spice', 'pepper', 'cumin', 'coriander', 'turmeric', 'paprika', 'cinnamon', 'ginger powder', 'oregano', 'basil', 'thyme', 'rosemary', 'herb'])) return '🌿';
  if (_has(n, ['vanilla', 'extract'])) return '🫙';

  return fallback.emoji;
}

bool _has(String name, List<String> keywords) =>
    keywords.any((k) => name.contains(k));
