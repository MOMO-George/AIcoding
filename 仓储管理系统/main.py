import json
import random
import string
from datetime import datetime


# ====================== 数据管理模块 ======================
class DataManager:
    @staticmethod
    def load_data(filename):
        """加载数据文件"""
        try:
            with open(filename, 'r', encoding='utf-8') as f:
                return json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            # 文件不存在或为空，返回空列表
            return []

    @staticmethod
    def save_data(data, filename):
        """保存数据到文件"""
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=4)

    @staticmethod
    def init_data_files():
        """初始化数据文件"""
        files = {
            'user_info.txt': [{"id": 1, "username": "Tom", "password": "sads-=asd=iopalopas5"},
                            {"id": 2, "username": "Sam", "password":"saszxcrrsd6lzxc19qas5"},
                            {"id": 3, "username": "Lina", "password": "sasdwiruis783xs5"},
	                        {"id": 4, "username": "WangLin", "password": "sdswrfx7893"}],
            'category_info.txt': [{"id": 1, "categoryName": "饮料类"},
                            {"id": 2, "categoryName": "食品类"},
                            {"id": 3, "categoryName": "服装类"},
	                        {"id": 4, "categoryName": "饮料类"}],
            'supplier_info.txt': [{"id": 1, "supplierName": "成都创新食品生产厂"},
                            {"id": 2, "supplierName": "眉山食品加工厂"},
                            {"id": 3, "supplierName": "唐山服装制造厂"},
	                        {"id": 4, "supplierName": "义务食品生产厂"}],
            'product_info.txt': [{ "id": 1, "productName": "可口可乐", "categoryId": 1, "quantity": 100, "supplierId": 1, },
                            { "id": 2, "productName": "康师傅方便面", "categoryId": 2, "quantity": 50, "supplierId": 2, },
                            { "id": 3, "productName": "西装衬衣", "categoryId": 3, "quantity": 20, "supplierId": 3, },
	                        { "id": 4, "productName": "冰红茶", "categoryId": 4, "quantity": 150, "supplierId": 4, }],
            'inbound_record.txt': [{ "inbound_id": 1, "product_id": 1, "quantity": 50, "inbound_date": "2025-06-05", "supplierId": 1, "operation_time": "2025-06-05 10:00:00"},
                            { "inbound_id": 2, "product_id": 2, "quantity": 25, "inbound_date": "2025-03-15", "supplierId": 2, "operation_time": "2025-03-15 15:25:32"},
                            { "inbound_id": 3, "product_id": 3, "quantity": 10, "inbound_date": "2025-05-23", "supplierId": 3, "operation_time": "2025-05-23 16:45:04"},
	                        { "inbound_id": 4, "product_id": 4, "quantity": 70, "inbound_date": "2025-06-13", "supplierId": 4, "operation_time": "2025-06-13 21:25:36"}],
            'outbound_record.txt': [{ "outbound_id": 1, "product_id": 1, "quantity": 30, "outbound_ps": "小明购买了 30 瓶可乐", "operation_time": "2025-06-05 14:30:00"},
                            { "outbound_id": 2, "product_id": 2, "quantity": 10, "outbound_ps": "张三购买了 10 盒康师傅方便面", "operation_time": "2025-04-25 17:20:36"},
                            { "outbound_id": 3, "product_id": 3, "quantity": 3, "outbound_ps": "李四购买了 3 件西装衬衣", "operation_time": "2025-06-03 23:32:10"},
                            { "outbound_id": 4, "product_id": 4, "quantity": 20, "outbound_ps": "王五购买了 20 瓶冰红茶", "operation_time": "2025-06-15 16:01:16"}]
        }
        for filename, default_data in files.items():
            try:
                with open(filename, 'r', encoding='utf-8'):
                    pass
            except FileNotFoundError:
                with open(filename, 'w', encoding='utf-8') as f:
                    json.dump(default_data, f, ensure_ascii=False, indent=4)



# ====================== 用户认证模块 ======================
class UserAuth:
    @staticmethod
    def caesar_cipher(text, shift=3, mode='encrypt'):
        """凯撒加密/解密"""
        result = []
        for char in text:
            if char.isalpha():
                shift_amount = shift if mode == 'encrypt' else -shift
                if char.islower():
                    new_char = chr(((ord(char) - ord('a') + shift_amount) % 26) + ord('a'))
                else:
                    new_char = chr(((ord(char) - ord('A') + shift_amount) % 26) + ord('A'))
                result.append(new_char)
            else:
                result.append(char)
        return ''.join(result)

    @staticmethod
    def generate_salt(length=16):
        """生成随机盐值"""
        return ''.join(random.choices(string.ascii_letters + string.digits, k=length))

    @staticmethod
    def encrypt_password(password):
        """加密密码（加盐）"""
        # 第一次凯撒加密
        encrypted = UserAuth.caesar_cipher(password)
        # 生成盐值
        salt = UserAuth.generate_salt()
        # 拼接盐值和加密后的密码
        combined = salt + encrypted
        # 第二次凯撒加密
        return UserAuth.caesar_cipher(combined)

    @staticmethod
    def decrypt_password(encrypted_password):
        """解密密码（去盐）"""
        # 第一次凯撒解密
        decrypted = UserAuth.caesar_cipher(encrypted_password, mode='decrypt')
        # 提取盐值（前16位）
        salt = decrypted[:16]
        # 提取真实加密密码
        encrypted = decrypted[16:]
        # 第二次凯撒解密
        return UserAuth.caesar_cipher(encrypted, mode='decrypt')

    @staticmethod
    def login():
        """用户登录"""
        username = input("请输入用户名: ")
        password = input("请输入密码: ")

        users = DataManager.load_data('user_info.txt')

        for user in users:
            if user['username'] == username:
                # 解密存储的密码
                stored_password = user['password']
                if stored_password == password:
                    print("登录成功!")
                    return True, username
                else:
                    print("用户名或密码错误!")
                    return False, None

        print("用户名不存在!")
        return False, None

    @staticmethod
    def register():
        """用户注册"""
        username = input("请输入用户名: ")

        # 检查用户名是否已存在
        users = DataManager.load_data('user_info.txt')
        for user in users:
            if user['username'] == username:
                print("用户名已存在!")
                return False

        password = input("请输入密码: ")
        confirm_password = input("请再次输入密码: ")

        if password != confirm_password:
            print("两次输入的密码不一致!")
            return False

        # 加密密码
        encrypted_password = UserAuth.encrypt_password(password)

        # 生成用户ID
        user_id = 1 if not users else max(user['id'] for user in users) + 1

        # 添加新用户
        new_user = {
            'id': user_id,
            'username': username,
            'password': encrypted_password
        }
        users.append(new_user)

        # 保存用户信息
        DataManager.save_data(users, 'user_info.txt')

        print("注册成功! 请登录。")
        return True


# ====================== 库存查询模块 ======================
class InventoryQuery:
    @staticmethod
    def exact_query(product_id):
        """精确查询"""
        products = DataManager.load_data('product_info.txt')
        categories = DataManager.load_data('category_info.txt')
        suppliers = DataManager.load_data('supplier_info.txt')

        for product in products:
            if product['id'] == product_id:
                # 获取类别名称
                category_name = next(
                    (cat['categoryName'] for cat in categories if cat['id'] == product['categoryId']),
                    '未知类别'
                )
                # 获取供应商名称
                supplier_name = next(
                    (sup['supplierName'] for sup in suppliers if sup['id'] == product['supplierId']),
                    '未知供应商'
                )

                print("\n查询结果:")
                print(f"商品编号: {product['id']}")
                print(f"商品名称: {product['productName']}")
                print(f"商品类别: {category_name}")
                print(f"库存数量: {product['quantity']}")
                print(f"供应商: {supplier_name}")
                return

        print("未找到该商品!")

    @staticmethod
    def fuzzy_query(keywords, mode='all'):
        """模糊查询"""
        products = DataManager.load_data('product_info.txt')
        categories = DataManager.load_data('category_info.txt')
        suppliers = DataManager.load_data('supplier_info.txt')

        keyword_list = [kw.strip() for kw in keywords.split(',')]
        results = []

        for product in products:
            name = product['productName']

            if mode == 'all':
                # 全包含模式
                if all(keyword in name for keyword in keyword_list):
                    results.append(product)
            else:
                # 任意包含模式
                if any(keyword in name for keyword in keyword_list):
                    results.append(product)

        if not results:
            print("未找到符合条件的商品!")
            return

        print(f"\n找到 {len(results)} 个匹配商品:")
        for product in results:
            # 获取类别名称
            category_name = next(
                (cat['categoryName'] for cat in categories if cat['id'] == product['categoryId']),
                '未知类别'
            )
            # 获取供应商名称
            supplier_name = next(
                (sup['supplierName'] for sup in suppliers if sup['id'] == product['supplierId']),
                '未知供应商'
            )

            print("\n商品编号:", product['id'])
            print("商品名称:", product['productName'])
            print("商品类别:", category_name)
            print("库存数量:", product['quantity'])
            print("供应商:", supplier_name)

    @staticmethod
    def range_query(min_qty, max_qty):
        """库存范围查询"""
        products = DataManager.load_data('product_info.txt')
        categories = DataManager.load_data('category_info.txt')
        suppliers = DataManager.load_data('supplier_info.txt')

        results = [p for p in products if min_qty <= p['quantity'] <= max_qty]

        if not results:
            print("未找到库存数量在指定范围内的商品!")
            return

        print(f"\n找到 {len(results)} 个匹配商品:")
        for product in results:
            # 获取类别名称
            category_name = next(
                (cat['categoryName'] for cat in categories if cat['id'] == product['categoryId']),
                '未知类别'
            )
            # 获取供应商名称
            supplier_name = next(
                (sup['supplierName'] for sup in suppliers if sup['id'] == product['supplierId']),
                '未知供应商'
            )

            print("\n商品编号:", product['id'])
            print("商品名称:", product['productName'])
            print("商品类别:", category_name)
            print("库存数量:", product['quantity'])
            print("供应商:", supplier_name)


# ====================== 入库操作模块 ======================
class InventoryInbound:
    @staticmethod
    def add_inbound():
        """添加入库记录"""
        product_id = input("请输入商品编号: ")
        try:
            product_id = int(product_id)
        except ValueError:
            print("商品编号必须是数字!")
            return

        quantity = input("请输入进货数量: ")
        try:
            quantity = int(quantity)
            if quantity <= 0:
                print("进货数量必须为正数!")
                return
        except ValueError:
            print("进货数量必须是数字!")
            return

        supplier_id = input("请输入供应商ID: ")
        try:
            supplier_id = int(supplier_id)
        except ValueError:
            print("供应商ID必须是数字!")
            return

        # 检查供应商是否存在
        suppliers = DataManager.load_data('supplier_info.txt')
        supplier_exists = any(sup['id'] == supplier_id for sup in suppliers)
        if not supplier_exists:
            print("供应商不存在!")
            return

        products = DataManager.load_data('product_info.txt')
        product_exists = any(p['id'] == product_id for p in products)

        if not product_exists:
            print("商品不存在，需要创建新商品!")
            product_name = input("请输入商品名称: ")
            if not product_name:
                print("商品名称不能为空!")
                return

            category_id = input("请输入商品类别ID: ")
            try:
                category_id = int(category_id)
            except ValueError:
                print("商品类别ID必须是数字!")
                return

            # 检查类别是否存在
            categories = DataManager.load_data('category_info.txt')
            category_exists = any(cat['id'] == category_id for cat in categories)
            if not category_exists:
                print("商品类别不存在!")
                return

            # 创建新商品
            new_product = {
                'id': product_id,
                'productName': product_name,
                'categoryId': category_id,
                'quantity': quantity,
                'supplierId': supplier_id
            }
            products.append(new_product)
            DataManager.save_data(products, 'product_info.txt')
            print("新商品创建成功!")
        else:
            # 更新现有商品库存
            for product in products:
                if product['id'] == product_id:
                    product['quantity'] += quantity
                    break
            DataManager.save_data(products, 'product_info.txt')
            print("商品库存更新成功!")

        # 添加入库记录
        inbound_records = DataManager.load_data('inbound_record.txt')
        inbound_id = 1 if not inbound_records else max(r['inbound_id'] for r in inbound_records) + 1

        current_date = datetime.now().strftime("%Y-%m-%d")
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        new_record = {
            'inbound_id': inbound_id,
            'product_id': product_id,
            'quantity': quantity,
            'inbound_date': current_date,
            'supplierId': supplier_id,
            'operation_time': current_time
        }
        inbound_records.append(new_record)
        DataManager.save_data(inbound_records, 'inbound_record.txt')

        print("\n入库单:")
        print(f"入库单号: {inbound_id}")
        print(f"商品编号: {product_id}")
        print(f"进货数量: {quantity}")
        print(f"进货日期: {current_date}")
        print(f"供应商ID: {supplier_id}")
        print(f"入库时间: {current_time}")
        print("入库操作已完成!")


# ====================== 出库操作模块 ======================
class InventoryOutbound:
    @staticmethod
    def add_outbound():
        """添加出库记录"""
        product_id = input("请输入商品编号: ")
        try:
            product_id = int(product_id)
        except ValueError:
            print("商品编号必须是数字!")
            return

        quantity = input("请输入出库数量: ")
        try:
            quantity = int(quantity)
            if quantity <= 0:
                print("出库数量必须为正数!")
                return
        except ValueError:
            print("出库数量必须是数字!")
            return

        remark = input("请输入出库备注: ")

        # 检查商品是否存在
        products = DataManager.load_data('product_info.txt')
        product = next((p for p in products if p['id'] == product_id), None)
        if not product:
            print("商品不存在!")
            return

        # 检查库存是否足够
        if product['quantity'] < quantity:
            print("库存不足!")
            return

        # 更新库存
        product['quantity'] -= quantity
        DataManager.save_data(products, 'product_info.txt')

        # 添加出库记录
        outbound_records = DataManager.load_data('outbound_record.txt')
        outbound_id = 1 if not outbound_records else max(r['outbound_id'] for r in outbound_records) + 1

        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        new_record = {
            'outbound_id': outbound_id,
            'product_id': product_id,
            'quantity': quantity,
            'outbound_ps': remark,
            'operation_time': current_time
        }
        outbound_records.append(new_record)
        DataManager.save_data(outbound_records, 'outbound_record.txt')

        # 获取商品详情
        categories = DataManager.load_data('category_info.txt')
        suppliers = DataManager.load_data('supplier_info.txt')

        category_name = next(
            (cat['categoryName'] for cat in categories if cat['id'] == product['categoryId']),
            '未知类别'
        )
        supplier_name = next(
            (sup['supplierName'] for sup in suppliers if sup['id'] == product['supplierId']),
            '未知供应商'
        )

        print("\n出库单:")
        print(f"出库单号: {outbound_id}")
        print(f"商品编号: {product_id}")
        print(f"商品名称: {product['productName']}")
        print(f"商品类别: {category_name}")
        print(f"出库数量: {quantity}")
        print(f"剩余库存: {product['quantity']}")
        print(f"供应商: {supplier_name}")
        print(f"出库备注: {remark}")
        print(f"出库时间: {current_time}")
        print("出库操作已完成!")


# ====================== 信息更新模块 ======================
class InventoryUpdate:
    @staticmethod
    def update_category():
        """更新商品类别"""
        print("\n商品类别管理")
        print("1. 添加新类别")
        print("2. 修改现有类别")
        print("3. 返回")

        choice = input("请选择操作: ")

        categories = DataManager.load_data('category_info.txt')

        if choice == '1':
            # 添加新类别
            category_name = input("请输入新类别名称: ")
            if not category_name:
                print("类别名称不能为空!")
                return

            category_id = 1 if not categories else max(cat['id'] for cat in categories) + 1

            new_category = {
                'id': category_id,
                'categoryName': category_name
            }
            categories.append(new_category)
            DataManager.save_data(categories, 'category_info.txt')
            print("类别添加成功!")

        elif choice == '2':
            # 修改现有类别
            category_id = input("请输入要修改的类别ID: ")
            try:
                category_id = int(category_id)
            except ValueError:
                print("类别ID必须是数字!")
                return

            category = next((cat for cat in categories if cat['id'] == category_id), None)
            if not category:
                print("类别不存在!")
                return

            new_name = input(f"请输入新的类别名称 (当前: {category['categoryName']}): ")
            if not new_name:
                print("类别名称不能为空!")
                return

            category['categoryName'] = new_name
            DataManager.save_data(categories, 'category_info.txt')
            print("类别修改成功!")

        elif choice == '3':
            return
        else:
            print("无效的选择!")

    @staticmethod
    def update_supplier():
        """更新供应商"""
        print("\n供应商管理")
        print("1. 添加新供应商")
        print("2. 修改现有供应商")
        print("3. 返回")

        choice = input("请选择操作: ")

        suppliers = DataManager.load_data('supplier_info.txt')

        if choice == '1':
            # 添加新供应商
            supplier_name = input("请输入新供应商名称: ")
            if not supplier_name:
                print("供应商名称不能为空!")
                return

            supplier_id = 1 if not suppliers else max(sup['id'] for sup in suppliers) + 1

            new_supplier = {
                'id': supplier_id,
                'supplierName': supplier_name
            }
            suppliers.append(new_supplier)
            DataManager.save_data(suppliers, 'supplier_info.txt')
            print("供应商添加成功!")

        elif choice == '2':
            # 修改现有供应商
            supplier_id = input("请输入要修改的供应商ID: ")
            try:
                supplier_id = int(supplier_id)
            except ValueError:
                print("供应商ID必须是数字!")
                return

            supplier = next((sup for sup in suppliers if sup['id'] == supplier_id), None)
            if not supplier:
                print("供应商不存在!")
                return

            new_name = input(f"请输入新的供应商名称 (当前: {supplier['supplierName']}): ")
            if not new_name:
                print("供应商名称不能为空!")
                return

            supplier['supplierName'] = new_name
            DataManager.save_data(suppliers, 'supplier_info.txt')
            print("供应商修改成功!")

        elif choice == '3':
            return
        else:
            print("无效的选择!")

    @staticmethod
    def update_product():
        """更新商品信息"""
        print("\n商品信息管理")
        print("1. 添加新商品")
        print("2. 修改现有商品")
        print("3. 直接调整库存数量")
        print("4. 返回")

        choice = input("请选择操作: ")

        products = DataManager.load_data('product_info.txt')
        categories = DataManager.load_data('category_info.txt')
        suppliers = DataManager.load_data('supplier_info.txt')

        if choice == '1':
            # 添加新商品
            product_name = input("请输入商品名称: ")
            if not product_name:
                print("商品名称不能为空!")
                return

            category_id = input("请输入商品类别ID: ")
            try:
                category_id = int(category_id)
            except ValueError:
                print("商品类别ID必须是数字!")
                return

            # 检查类别是否存在
            if not any(cat['id'] == category_id for cat in categories):
                print("商品类别不存在!")
                return

            supplier_id = input("请输入供应商ID: ")
            try:
                supplier_id = int(supplier_id)
            except ValueError:
                print("供应商ID必须是数字!")
                return

            # 检查供应商是否存在
            if not any(sup['id'] == supplier_id for sup in suppliers):
                print("供应商不存在!")
                return

            quantity = input("请输入初始库存数量: ")
            try:
                quantity = int(quantity)
                if quantity < 0:
                    print("库存数量不能为负数!")
                    return
            except ValueError:
                print("库存数量必须是数字!")
                return

            product_id = 1 if not products else max(p['id'] for p in products) + 1

            new_product = {
                'id': product_id,
                'productName': product_name,
                'categoryId': category_id,
                'quantity': quantity,
                'supplierId': supplier_id
            }
            products.append(new_product)
            DataManager.save_data(products, 'product_info.txt')
            print("商品添加成功!")

        elif choice == '2':
            # 修改现有商品
            product_id = input("请输入要修改的商品ID: ")
            try:
                product_id = int(product_id)
            except ValueError:
                print("商品ID必须是数字!")
                return

            product = next((p for p in products if p['id'] == product_id), None)
            if not product:
                print("商品不存在!")
                return

            new_name = input(f"请输入新的商品名称 (当前: {product['productName']}): ")
            if new_name:
                product['productName'] = new_name

            new_category_id = input(f"请输入新的类别ID (当前: {product['categoryId']}): ")
            if new_category_id:
                try:
                    new_category_id = int(new_category_id)
                    # 检查类别是否存在
                    if not any(cat['id'] == new_category_id for cat in categories):
                        print("商品类别不存在!")
                        return
                    product['categoryId'] = new_category_id
                except ValueError:
                    print("类别ID必须是数字!")
                    return

            new_supplier_id = input(f"请输入新的供应商ID (当前: {product['supplierId']}): ")
            if new_supplier_id:
                try:
                    new_supplier_id = int(new_supplier_id)
                    # 检查供应商是否存在
                    if not any(sup['id'] == new_supplier_id for sup in suppliers):
                        print("供应商不存在!")
                        return
                    product['supplierId'] = new_supplier_id
                except ValueError:
                    print("供应商ID必须是数字!")
                    return

            DataManager.save_data(products, 'product_info.txt')
            print("商品修改成功!")

        elif choice == '3':
            # 直接调整库存数量
            product_id = input("请输入商品ID: ")
            try:
                product_id = int(product_id)
            except ValueError:
                print("商品ID必须是数字!")
                return

            product = next((p for p in products if p['id'] == product_id), None)
            if not product:
                print("商品不存在!")
                return

            new_quantity = input(f"请输入新的库存数量 (当前: {product['quantity']}): ")
            try:
                new_quantity = int(new_quantity)
                if new_quantity < 0:
                    print("库存数量不能为负数!")
                    return
                product['quantity'] = new_quantity
            except ValueError:
                print("库存数量必须是数字!")
                return

            DataManager.save_data(products, 'product_info.txt')
            print("库存数量调整成功!")

        elif choice == '4':
            return
        else:
            print("无效的选择!")


# ====================== 库存盘点模块 ======================
class InventoryAudit:
    @staticmethod
    def audit_inventory(sort_by='category', order='asc'):
        """库存盘点"""
        products = DataManager.load_data('product_info.txt')
        categories = DataManager.load_data('category_info.txt')
        suppliers = DataManager.load_data('supplier_info.txt')

        if not products:
            print("没有商品可盘点!")
            return

        # 为每个商品添加类别名称和供应商名称
        for product in products:
            product['categoryName'] = next(
                (cat['categoryName'] for cat in categories if cat['id'] == product['categoryId']),
                '未知类别'
            )
            product['supplierName'] = next(
                (sup['supplierName'] for sup in suppliers if sup['id'] == product['supplierId']),
                '未知供应商'
            )

        # 排序
        if sort_by == 'category':
            # 按类别排序，同类按库存数量排序
            products.sort(key=lambda x: (x['categoryName'],
                                         x['quantity'] if order == 'asc' else -x['quantity']))
        else:
            # 按库存数量排序
            products.sort(key=lambda x: x['quantity'] if order == 'asc' else -x['quantity'])

        # 显示盘点结果
        print("\n库存盘点结果:")
        current_category = None
        for product in products:
            if sort_by == 'category' and product['categoryName'] != current_category:
                current_category = product['categoryName']
                print(f"\n=== 类别: {current_category} ===")

            print(f"商品编号: {product['id']}")
            print(f"商品名称: {product['productName']}")
            print(f"库存数量: {product['quantity']}")
            print(f"供应商: {product['supplierName']}")
            print("-" * 30)

        # 生成盘点报告
        report_filename = 'inventory_audit_report.txt'
        with open(report_filename, 'w', encoding='utf-8') as f:
            f.write("库存盘点报告\n")
            f.write(f"生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(
                f"排序方式: 按{'类别' if sort_by == 'category' else '库存数量'} {'升序' if order == 'asc' else '降序'}\n")
            f.write("=" * 50 + "\n")

            current_category = None
            for product in products:
                if sort_by == 'category' and product['categoryName'] != current_category:
                    current_category = product['categoryName']
                    f.write(f"\n=== 类别: {current_category} ===\n")

                f.write(f"商品编号: {product['id']}\n")
                f.write(f"商品名称: {product['productName']}\n")
                f.write(f"库存数量: {product['quantity']}\n")
                f.write(f"供应商: {product['supplierName']}\n")
                f.write("-" * 30 + "\n")

        print(f"\n盘点报告已生成，保存在 {report_filename}")


# ====================== 主菜单与界面模块 ======================
class MainMenu:
    @staticmethod
    def show_login_menu():
        """显示登录菜单"""
        print("\n仓储管理系统")
        print("1. 登录")
        print("2. 注册")
        print("3. 退出")

        choice = input("请选择操作: ")
        return choice

    @staticmethod
    def show_main_menu(username):
        """显示主菜单"""
        print(f"\n欢迎, {username}!")
        print("1. 库存查询")
        print("2. 入库操作")
        print("3. 出库操作")
        print("4. 信息更新")
        print("5. 库存盘点")
        print("6. 退出登录")

        choice = input("请选择操作: ")
        return choice

    @staticmethod
    def show_query_menu():
        """显示查询菜单"""
        print("\n库存查询")
        print("1. 精确查询")
        print("2. 模糊查询")
        print("3. 库存范围查询")
        print("4. 返回")

        choice = input("请选择查询方式: ")
        return choice

    @staticmethod
    def show_update_menu():
        """显示更新菜单"""
        print("\n信息更新")
        print("1. 商品类别管理")
        print("2. 供应商管理")
        print("3. 商品信息管理")
        print("4. 返回")

        choice = input("请选择操作: ")
        return choice

    @staticmethod
    def show_audit_menu():
        """显示盘点菜单"""
        print("\n库存盘点")
        print("1. 按类别排序")
        print("2. 按库存数量排序")
        print("3. 返回")

        choice = input("请选择排序方式: ")
        return choice

    @staticmethod
    def run():
        """运行主程序"""
        DataManager.init_data_files()

        logged_in = False
        username = None

        while True:
            if not logged_in:
                choice = MainMenu.show_login_menu()

                if choice == '1':
                    logged_in, username = UserAuth.login()
                elif choice == '2':
                    UserAuth.register()
                elif choice == '3':
                    print("感谢使用仓储管理系统，再见!")
                    break
                else:
                    print("无效的选择，请重新输入!")
            else:
                choice = MainMenu.show_main_menu(username)

                if choice == '1':
                    # 库存查询
                    while True:
                        query_choice = MainMenu.show_query_menu()

                        if query_choice == '1':
                            # 精确查询
                            product_id = input("请输入商品编号: ")
                            try:
                                product_id = int(product_id)
                                InventoryQuery.exact_query(product_id)
                            except ValueError:
                                print("商品编号必须是数字!")
                        elif query_choice == '2':
                            # 模糊查询
                            keywords = input("请输入查询关键词(多个关键词用逗号分隔): ")
                            mode = input("请选择查询模式 (1.全包含 2.任意包含): ")
                            InventoryQuery.fuzzy_query(
                                keywords,
                                mode='all' if mode == '1' else 'any'
                            )
                        elif query_choice == '3':
                            # 库存范围查询
                            min_qty = input("请输入最小库存数量: ")
                            max_qty = input("请输入最大库存数量: ")
                            try:
                                min_qty = int(min_qty)
                                max_qty = int(max_qty)
                                if min_qty < 0 or max_qty < 0:
                                    print("库存数量不能为负数!")
                                elif min_qty > max_qty:
                                    print("最小库存不能大于最大库存!")
                                else:
                                    InventoryQuery.range_query(min_qty, max_qty)
                            except ValueError:
                                print("库存数量必须是数字!")
                        elif query_choice == '4':
                            break
                        else:
                            print("无效的选择!")

                elif choice == '2':
                    # 入库操作
                    InventoryInbound.add_inbound()

                elif choice == '3':
                    # 出库操作
                    InventoryOutbound.add_outbound()

                elif choice == '4':
                    # 信息更新
                    while True:
                        update_choice = MainMenu.show_update_menu()

                        if update_choice == '1':
                            InventoryUpdate.update_category()
                        elif update_choice == '2':
                            InventoryUpdate.update_supplier()
                        elif update_choice == '3':
                            InventoryUpdate.update_product()
                        elif update_choice == '4':
                            break
                        else:
                            print("无效的选择!")

                elif choice == '5':
                    # 库存盘点
                    while True:
                        audit_choice = MainMenu.show_audit_menu()

                        if audit_choice == '1':
                            order = input("请选择排序顺序 (1.升序 2.降序): ")
                            InventoryAudit.audit_inventory(
                                sort_by='category',
                                order='asc' if order == '1' else 'desc'
                            )
                        elif audit_choice == '2':
                            order = input("请选择排序顺序 (1.升序 2.降序): ")
                            InventoryAudit.audit_inventory(
                                sort_by='quantity',
                                order='asc' if order == '1' else 'desc'
                            )
                        elif audit_choice == '3':
                            break
                        else:
                            print("无效的选择!")

                elif choice == '6':
                    logged_in = False
                    username = None
                    print("已退出登录!")

                else:
                    print("无效的选择，请重新输入!")


# ====================== 程序入口 ======================
if __name__ == "__main__":
    MainMenu.run()