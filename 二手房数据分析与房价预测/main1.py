import pandas as pd
import numpy as np
import re
from sklearn.preprocessing import LabelEncoder

# 设置中文显示（预处理中若涉及临时绘图需保留，此处主要为后续处理准备）
import matplotlib.pyplot as plt

plt.rcParams['font.sans-serif'] = ['SimHei']
plt.rcParams['axes.unicode_minus'] = False  # 用来正常显示负号


# 1. 数据预处理函数定义
def dealYear(year_str):
    try:
        # 提取数字
        match = re.search(r'\d+', str(year_str))
        if match:
            year_val = int(match.group())
            # 计算房龄 (2022 - 数值)
            return 2022 - year_val
        return np.nan
    except:
        return np.nan


def dealType(df_source):
    # 创建值为0的 DataFrame，列为 室 和 厅
    temp_df = pd.DataFrame(0, index=df_source.index, columns=['室', '厅'])

    # 循环使用正则表达式获取数值
    for index, row in df_source.iterrows():
        type_str = str(row['户型'])
        # 提取室
        shi_match = re.search(r'(\d+)室', type_str)
        if shi_match:
            temp_df.at[index, '室'] = int(shi_match.group(1))

        # 提取厅
        ting_match = re.search(r'(\d+)厅', type_str)
        if ting_match:
            temp_df.at[index, '厅'] = int(ting_match.group(1))

    return temp_df


def clean_to_float(val):
    if pd.isna(val): return np.nan
    # 替换中文单位为空字符，保留数字和小数点
    clean_str = re.sub(r'[^\d.]', '', str(val))
    try:
        return float(clean_str)
    except:
        return np.nan


# 2. 数据加载与预处理主流程
if __name__ == "__main__":
    # 0. 数据加载
    df = pd.read_excel('最新发布的北京二手房数据.xlsx')

    # 处理户型数据
    # 第一步：删除户型列中的所有空格（包括首尾和中间的空格）
    df['户型'] = df['户型'].str.replace(r'\s+', '', regex=True)
    # 第二步：将户型中的"房间"替换为"室"
    df['户型'] = df['户型'].str.replace('房间', '室')
    type_df = dealType(df)
    df = df.join(type_df)  # 横向连接

    # 处理年份（计算房龄）
    df['房龄'] = df['年份'].apply(lambda x: dealYear(x))

    # 清洗面积、总价、单价并转换为浮点型
    df['面积'] = df['面积'].apply(clean_to_float)
    df['总价'] = df['总价'].apply(clean_to_float)
    df['单价'] = df['单价'].apply(clean_to_float)

    # 修改列标签
    rename_map = {
        '面积': '面积(平方米)',
        '总价': '总价(万元)',
        '单价': '单价(元/平方米)'
    }
    df.rename(columns=rename_map, inplace=True)

    # 筛选所需列
    cols_required = ['小区名', '所在街道或镇', '所在区', '户型', '面积(平方米)', '朝向', '装修', '楼层', '房龄', '结构',
                     '总价(万元)', '单价(元/平方米)', '房源标签', '室', '厅']
    df = df[cols_required]

    # 异常值处理
    # 删除包含“车位”的行
    df = df[~df['户型'].astype(str).str.contains('车位')]

    # ========== 删除“结构”列为“暂无数据”的行 ==========
    # 先去除结构列字符串首尾空格，避免因空格导致筛选失效
    df['结构'] = df['结构'].str.strip()

    # 过滤房龄范围
    df = df[((df['房龄'] >= 0) & (df['房龄'] <= 50)) | df['房龄'].isna()]

    # 重复值处理
    df.drop_duplicates(keep='first', inplace=True)

    # 缺失值处理
    print(f"删除房龄缺失值前行数: {len(df)}")
    df.dropna(subset=['房龄'], inplace=True)
    print(f"删除房龄缺失值后行数: {len(df)}")
    df['房源标签'] = df['房源标签'].fillna('不近地铁')

    # 连续数据离散化
    # 面积分箱
    area_bins = [0, 50, 80, 110, 140, 170, 200, float('inf')]
    area_labels = ['50平方米以下', '50~80平方米', '80~110平方米', '110~140平方米',
                   '140~170平方米', '170~200平方米', '200平方米以上']
    df['面积区间'] = pd.cut(df['面积(平方米)'], bins=area_bins, labels=area_labels, right=False)

    # 总价分箱
    price_bins = [0, 150, 350, 500, 700, 900, 2000, float('inf')]
    price_labels = ['150万元以下', '150万~350万元', '350万~500万元', '500万~700万元',
                    '700万~900万元', '900万~2000万元', '2000万元以上']
    df['总价区间'] = pd.cut(df['总价(万元)'], bins=price_bins, labels=price_labels, right=False)

    # 字符型数据编码
    encode_cols = ['所在区', '装修', '结构', '房源标签', '朝向']
    le = LabelEncoder()
    for col in encode_cols:
        df[col + '_Code'] = le.fit_transform(df[col].astype(str))

    # 保存预处理后的数据
    output_file = "最新发布的北京二手房数据_预处理.xlsx"
    df.to_excel(output_file, index=False)
    print(f"预处理数据已保存至: {output_file}")

