import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

# 设置绘图样式与中文显示
plt.style.use('seaborn-v0_8')
plt.rcParams['font.sans-serif'] = ['SimHei']
plt.rcParams['axes.unicode_minus'] = False  # 用来正常显示负号


if __name__ == "__main__":
    # 加载预处理后的数据
    input_file = "最新发布的北京二手房数据_预处理.xlsx"
    df = pd.read_excel(input_file)
    print(f"已加载预处理数据，共 {len(df)} 行")

    # (1) 各区二手房数量和均价分析
    district_stats = df.groupby('所在区').agg({
        '单价(元/平方米)': 'mean',
        '所在区': 'count'
    }).rename(columns={'所在区': '数量', '单价(元/平方米)': '均价'}).sort_values('数量', ascending=False)

    fig, ax1 = plt.subplots(figsize=(14, 7))
    bars = ax1.bar(district_stats.index, district_stats['数量'], color='skyblue', alpha=0.7, label='房源数量')
    ax1.set_xlabel('所在区')
    ax1.set_ylabel('房源数量 (套)', color='blue')
    ax1.tick_params(axis='y', labelcolor='blue')
    ax1.set_title('各区二手房数量和均价分析', fontsize=14, fontweight='bold')
    ax1.tick_params(axis='x', rotation=45)

    ax2 = ax1.twinx()
    line = ax2.plot(district_stats.index, district_stats['均价'], color='red', marker='o', linewidth=2, label='平均单价')
    ax2.set_ylabel('平均单价 (元/平方米)', color='red')
    ax2.tick_params(axis='y', labelcolor='red')

    lines1, labels1 = ax1.get_legend_handles_labels()
    lines2, labels2 = ax2.get_legend_handles_labels()
    ax1.legend(lines1 + lines2, labels1 + labels2, loc='upper right')

    plt.tight_layout()
    plt.savefig('1_各区二手房数量和均价分析.png', dpi=300, bbox_inches='tight')
    plt.show()
    print("分析1：各区二手房数量和均价分析图表已保存")

    # (2) 北京二手房面积和总价区间占比分析
    fig ,(ax1, ax2) = plt.subplots(1, 2, figsize=(16, 7))

    # 总价区间占比
    price_counts = df['总价区间'].value_counts()
    ax1.pie(price_counts, labels=price_counts.index, autopct='%1.1f%%', startangle=140,
            colors=sns.color_palette('bright'))
    ax1.set_title('北京二手房总价区间占比', fontsize=12, fontweight='bold')

    # 面积区间占比
    area_counts = df['面积区间'].value_counts()
    ax2.pie(area_counts, labels=area_counts.index, autopct='%1.1f%%', startangle=140,
            colors=sns.color_palette('pastel'))
    ax2.set_title('北京二手房面积区间占比', fontsize=12, fontweight='bold')

    plt.tight_layout()
    plt.savefig('2_北京及各区二手房面积和总价区间占比分析.png', dpi=300, bbox_inches='tight')
    plt.show()
    print("分析2：北京二手房面积和总价区间占比分析图表已保存")

    # (3) 相关性分析
    corr_cols = ['房龄', '朝向_Code', '装修_Code', '面积(平方米)', '单价(元/平方米)']
    corr_matrix = df[corr_cols].corr()
    sns.heatmap(corr_matrix, annot=True, cmap='coolwarm', fmt=".2f")
    plt.title('二手房特征与均价相关性分析')
    plt.tight_layout()
    plt.savefig('3_二手房特征与均价相关性分析.png', dpi=300, bbox_inches='tight')
    plt.show()
    print("分析3：二手房特征与均价相关性分析图表已保存")

    # (4) 是否靠近地铁的不同装修二手房均价分析
    subway_decor = df.groupby(['房源标签', '装修'])['单价(元/平方米)'].mean().unstack()

    fig, ax = plt.subplots(figsize=(10, 6))
    subway_decor.plot(kind='bar', ax=ax, width=0.7, color=['orange', 'skyblue', 'green','black'])
    ax.set_xlabel('是否靠近地铁', fontsize=12)
    ax.set_ylabel('均价（元/平方米）', fontsize=12)
    ax.set_title('是否靠近地铁的不同装修二手房均价分析', fontsize=14, fontweight='bold')
    ax.legend(title='装修类型')
    ax.tick_params(axis='x', rotation=0)

    for container in ax.containers:
        ax.bar_label(container, fmt='%.0f', fontsize=10)

    plt.tight_layout()
    plt.savefig('4_地铁装修与均价分析.png', dpi=300, bbox_inches='tight')
    plt.show()
    print("分析4：地铁装修与均价分析图表已保存")

    # (5) 不同卧室数量的房屋均价分析
    room_price = df.groupby('室')['总价(万元)'].mean()
    room_price.plot(kind='bar', color='orange')
    plt.title('室数量的房屋均价')
    plt.xlabel('室')
    plt.ylabel('均价(万元)')
    plt.xticks(rotation=0)
    plt.tight_layout()
    plt.savefig('5_室数量的房屋均价分析.png', dpi=300, bbox_inches='tight')
    plt.show()
    print("分析5：室数量的房屋均价分析图表已保存")

    # (6) 各区域近地铁与非近地铁二手房源数量分析
    plt.figure(figsize=(14, 7))
    district_subway = pd.crosstab(df['所在区'], df['房源标签'])
    ax = district_subway.plot(kind='bar', stacked=False, ax=plt.gca())
    plt.title('各区域近地铁与非近地铁二手房源数量对比')
    plt.xlabel('所在区')
    plt.ylabel('房源数量')
    plt.xticks(rotation=45)

    # 在每个条形上添加数值
    for container in ax.containers:
        ax.bar_label(container, fmt='%.0f', fontsize=9)

    plt.legend(title='是否近地铁')
    plt.tight_layout()
    plt.savefig('6_各区域近地铁与非近地铁二手房源数量分析.png', dpi=300, bbox_inches='tight')
    plt.show()
    print("分析6：各区域近地铁与非近地铁二手房源数量分析图表已保存")