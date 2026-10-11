import os
import json
import time
import requests
from bs4 import BeautifulSoup

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9',
}

# Tự động tạo thư mục assets/data nếu chưa tồn tại
output_dir = os.path.join("assets", "data")
os.makedirs(output_dir, exist_ok=True)
output_path = os.path.join(output_dir, "recipes.json")

def get_recipe_links():
    """Lấy danh sách link từ các trang công thức phổ biến của Food Network"""
    urls = [
        "https://www.foodnetwork.com/recipes/recipes-a-z/xyz",
        "https://www.foodnetwork.com/recipes/photos/easy-chicken-recipes",
        "https://www.foodnetwork.com/recipes/photos/quick-and-easy-dinner-recipes"
    ]
    
    links = []
    for target_url in urls:
        print(f"Đang quét trang: {target_url}")
        try:
            res = requests.get(target_url, headers=HEADERS, timeout=10)
            if res.status_code == 200:
                soup = BeautifulSoup(res.text, 'html.parser')
                for a in soup.find_all('a', href=True):
                    href = a['href']
                    if '/recipes/' in href and href.endswith('.html') and '/photos/' not in href:
                        full_url = href if href.startswith('http') else f"https:{href}"
                        if full_url not in links:
                            links.append(full_url)
        except Exception as e:
            print(f"Không thể tải {target_url}: {e}")
            
    return links

def parse_recipe(url, index):
    try:
        res = requests.get(url, headers=HEADERS, timeout=10)
        if res.status_code != 200:
            return None
            
        soup = BeautifulSoup(res.text, 'html.parser')
        scripts = soup.find_all('script', type='application/ld+json')
        
        recipe_data = None
        for s in scripts:
            if not s.string:
                continue
            try:
                data = json.loads(s.string)
                if isinstance(data, list):
                    for item in data:
                        if item.get('@type') == 'Recipe':
                            recipe_data = item
                            break
                elif isinstance(data, dict) and data.get('@type') == 'Recipe':
                    recipe_data = data
                    break
            except Exception:
                continue
                
        if not recipe_data:
            return None

        # Trích xuất ảnh
        image_url = ""
        img = recipe_data.get('image')
        if isinstance(img, list) and img:
            image_url = img[0] if isinstance(img[0], str) else img[0].get('url', '')
        elif isinstance(img, dict):
            image_url = img.get('url', '')
        elif isinstance(img, str):
            image_url = img

        # Trích xuất Calories
        cal = 380
        nutri = recipe_data.get('nutrition', {})
        if 'calories' in nutri:
            val = str(nutri['calories']).split()[0]
            if val.isdigit():
                cal = int(val)

        # Trích xuất các bước nấu
        steps = []
        raw_steps = recipe_data.get('recipeInstructions', [])
        for step in raw_steps:
            if isinstance(step, dict) and 'text' in step:
                steps.append(step['text'].strip())
            elif isinstance(step, str):
                steps.append(step.strip())

        title = recipe_data.get('name', f'Recipe {index}')
        desc = recipe_data.get('description', title)
        time_cook = str(recipe_data.get('totalTime', '25 mins')).replace('PT', '').replace('M', ' mins')

        return {
            "id": str(index),
            "title": {"en": title, "vi": title},
            "description": {"en": desc, "vi": desc},
            "cook_time": {"en": time_cook, "vi": time_cook},
            "calories": cal,
            "protein": 35,
            "carbs": 25,
            "fat": 12,
            "image_url": image_url,
            "ingredients": recipe_data.get('recipeIngredient', []),
            "steps": {"en": steps, "vi": steps},
            "chef_advice": {
                "en": "Follow the cooking time carefully for best results.",
                "vi": "Canh chuẩn thời gian nấu để món ăn giữ được độ mềm mọng."
            }
        }
    except Exception as e:
        print(f"Lỗi đọc {url}: {e}")
        return None

def main():
    links = get_recipe_links()
    
    # Nếu FoodNetwork vẫn chặn IP trả về 0 link, tạo sẵn dữ liệu mẫu dự phòng để file không bị lỗi
    if not links:
        print("Trang web từ chối truy cập. Tự động khởi tạo dữ liệu mẫu chuẩn...")
        sample_recipes = [
            {
                "id": "1",
                "title": {"en": "Pan-Seared Herb Chicken", "vi": "Ức gà áp chảo sốt thảo mộc"},
                "description": {"en": "Juicy chicken breast with crispy skin.", "vi": "Ức gà mọng nước áp chảo ít dầu."},
                "cook_time": {"en": "20 mins", "vi": "20 phút"},
                "calories": 380,
                "protein": 42,
                "carbs": 12,
                "fat": 8,
                "image_url": "https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=600&q=80",
                "ingredients": ["Ức gà 200g", "Tiêu đen", "Dầu ô liu", "Bông cải xanh"],
                "steps": {
                    "en": ["Season chicken with pepper and salt.", "Sear both sides for 5 minutes."],
                    "vi": ["Ướp ức gà với tiêu và muối.", "Áp chảo mỗi mặt 5 phút."]
                },
                "chef_advice": {"en": "Do not overcook.", "vi": "Không nấu quá lửa để tránh bị khô."}
            },
            {
                "id": "2",
                "title": {"en": "Scrambled Eggs with Tomato", "vi": "Trứng xào cà chua"},
                "description": {"en": "Simple and nutritious home-style dish.", "vi": "Món ăn gia đình thanh đạm, giàu đạm."},
                "cook_time": {"en": "10 mins", "vi": "10 phút"},
                "calories": 250,
                "protein": 18,
                "carbs": 8,
                "fat": 14,
                "image_url": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=600&q=80",
                "ingredients": ["2 quả trứng", "1 quả cà chua", "Hành lá", "Gia vị"],
                "steps": {
                    "en": ["Whisk eggs.", "Sauté tomatoes until soft, then pour in eggs."],
                    "vi": ["Đánh đều trứng.", "Xào mềm cà chua rồi đổ trứng vào đảo đều."]
                },
                "chef_advice": {"en": "Cook eggs on low heat.", "vi": "Đảo trứng trên lửa nhỏ để trứng mềm mượt."}
            }
        ]
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(sample_recipes, f, ensure_ascii=False, indent=2)
        print(f"Đã tạo file dự phòng thành công tại: {output_path}")
        return

    print(f"-> Đã tìm thấy {len(links)} món ăn.")
    recipes = []
    limit = min(20, len(links))
    for i in range(limit):
        link = links[i]
        print(f"[{i+1}/{limit}] Đang cào: {link}")
        item = parse_recipe(link, i + 1)
        if item and item.get("image_url"):
            recipes.append(item)
        time.sleep(1)
        
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(recipes, f, ensure_ascii=False, indent=2)
        
    print(f"\n=> XONG! Đã lưu thành công vào: {output_path}")

if __name__ == "__main__":
    main()