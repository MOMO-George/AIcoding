import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from lightgbm import early_stopping
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LinearRegression, Ridge
from sklearn.ensemble import RandomForestRegressor, BaggingRegressor
from sklearn.tree import DecisionTreeRegressor
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
import warnings
from sklearn.model_selection import train_test_split, cross_val_score, GridSearchCV
from sklearn.ensemble import HistGradientBoostingRegressor
import xgboost as xgb
from sklearn.model_selection import GridSearchCV
import lightgbm as lgb
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers, callbacks

warnings.filterwarnings('ignore')
# 设置中文字体
plt.rcParams['font.sans-serif'] = ['SimHei']
plt.rcParams['axes.unicode_minus'] = False

# 加载预处理后的数据
df = pd.read_excel('最新发布的北京二手房数据_预处理.xlsx')

# 准备特征和目标变量
# 选择自变量（特征）
feature_columns = [
    '面积(平方米)', '室', '厅', '所在区_Code', '装修_Code',
    '结构_Code', '房源标签_Code', '朝向_Code', '房龄'
]

# 因变量（目标）
target_column = '单价(元/平方米)'

# 检查并处理缺失值
print("数据基本信息:")
print(f"总样本数: {len(df)}")
print(f"特征缺失情况:")
print(df[feature_columns + [target_column]].isnull().sum())

# 删除含有缺失值的行
df_clean = df[feature_columns + [target_column]].dropna()
print(f"清理后样本数: {len(df_clean)}")

# 3. 划分训练集和测试集 (80%训练, 20%测试)
X = df_clean[feature_columns]
y = df_clean[target_column]

X_train, X_test, y_train, y_test = train_test_split(
    X, y, train_size=0.8, random_state=42
)

print(f"\n训练集大小: {X_train.shape}")
print(f"测试集大小: {X_test.shape}")
#print(df['朝向'].unique()) #用于调试

# 存储结果
results = {}

# 定义评估函数
def calculate_metrics(y_true, y_pred):
    """计算多种评估指标"""
    mse = mean_squared_error(y_true, y_pred)
    rmse = np.sqrt(mse)
    mae = mean_absolute_error(y_true, y_pred)
    mape = np.mean(np.abs((y_true - y_pred) / y_true)) * 100
    smape = 2.0 * np.mean(np.abs(y_pred - y_true) / (np.abs(y_pred) + np.abs(y_true))) * 100
    r2 = r2_score(y_true, y_pred)

    return {
        'MSE': mse,
        'RMSE': rmse,
        'MAE': mae,
        'MAPE': mape,
        'SMAPE': smape,
        'R2': r2
    }

def print_metrics(metrics, model_name):
    """打印评估指标"""
    print(f"\n{model_name} 评估结果:")
    print(f"MSE: {metrics['MSE']:.2f}")
    print(f"RMSE: {metrics['RMSE']:.2f}元/㎡")
    print(f"MAE: {metrics['MAE']:.2f}元/㎡")
    print(f"MAPE: {metrics['MAPE']:.2f}%")
    print(f"SMAPE: {metrics['SMAPE']:.2f}%")
    print(f"R2: {metrics['R2']:.4f}")

# 观察训练特征图，用于调试
def plot_analysis(model, X_test, y_test, y_test_pred, feature_names):
    fig, axes = plt.subplots(1, 2, figsize=(16, 6))

    # --- 1. 特征重要性分析 ---
    importances = model.feature_importances_
    # 转换为 DataFrame 方便排序
    feat_imp = pd.DataFrame({'Feature': feature_names, 'Importance': importances})
    feat_imp = feat_imp.sort_values(by='Importance', ascending=False)

    sns.barplot(x='Importance', y='Feature', data=feat_imp, ax=axes[0], palette='viridis')
    axes[0].set_title('随机森林特征重要性排序')
    axes[0].set_xlabel('相对重要度')

    # --- 2. 预测残差分布图 ---
    residuals = y_test - y_test_pred
    sns.histplot(residuals, kde=True, ax=axes[1], color='skyblue')
    axes[1].axvline(x=0, color='red', linestyle='--')
    axes[1].set_title('预测残差分布 (真实值 - 预测值)')
    axes[1].set_xlabel('误差 (元/㎡)')
    axes[1].set_ylabel('频数')

    plt.tight_layout()
    plt.show()

    # --- 3. 预测值 vs 真实值 散点图 ---
    plt.figure(figsize=(8, 6))
    plt.scatter(y_test, y_test_pred, alpha=0.5, color='teal')
    plt.plot([y_test.min(), y_test.max()], [y_test.min(), y_test.max()], 'r--', lw=2)
    plt.title('预测值 vs 真实值对照图')
    plt.xlabel('真实单价 (元/㎡)')
    plt.ylabel('预测单价 (元/㎡)')
    plt.grid(True, linestyle='--', alpha=0.6)
    plt.show()

#1、线性回归模型
print("=" * 50)
print("训练线性回归模型...")
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)
lr_model = LinearRegression()
lr_model.fit(X_train_scaled, y_train)

# 预测
y_train_pred_lr = lr_model.predict(X_train_scaled)
y_test_pred_lr = lr_model.predict(X_test_scaled)

# 评估
train_metrics_lr = calculate_metrics(y_train, y_train_pred_lr)
test_metrics_lr = calculate_metrics(y_test, y_test_pred_lr)

print_metrics(train_metrics_lr, "线性回归-训练集")
print_metrics(test_metrics_lr, "线性回归-测试集")

results['线性回归'] = {
    'model': lr_model,
    'train_pred': y_train_pred_lr,
    'test_pred': y_test_pred_lr,
    'train_metrics': train_metrics_lr,
    'test_metrics': test_metrics_lr
}

# 2、岭回归模型
print("=" * 50)
print("训练岭回归模型...")
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)
ridge_model = Ridge(
    alpha=50.0,          # 增大alpha，加强正则化
    fit_intercept=True,  # 保留截距
    positive=True,       # 强制系数为正
    solver='auto',       # 自动选求解器
    random_state=42      # 固定种子，结果可复现
)
ridge_model.fit(X_train_scaled, y_train)

# 预测
y_train_pred_ridge = ridge_model.predict(X_train_scaled)
y_test_pred_ridge = ridge_model.predict(X_test_scaled)

# 评估
train_metrics_ridge = calculate_metrics(y_train, y_train_pred_ridge)
test_metrics_ridge = calculate_metrics(y_test, y_test_pred_ridge)

print_metrics(train_metrics_ridge, "岭回归-训练集")
print_metrics(test_metrics_ridge, "岭回归-测试集")

results['岭回归'] = {
    'model': ridge_model,
    'train_pred': y_train_pred_ridge,
    'test_pred': y_test_pred_ridge,
    'train_metrics': train_metrics_ridge,
    'test_metrics': test_metrics_ridge
}

# 3、随机森林回归模型
# 6.3 随机森林回归模型（基础调参版）
print("=" * 50)
print("训练随机森林回归模型...")
rf_model = RandomForestRegressor(
    n_estimators=200,  # 决策树数量（默认100，可适度增加）
    max_depth=15,  # 单棵树最大深度（限制深度防过拟合）
    min_samples_split=20,  # 节点分裂最小样本数（默认2，增大减少过拟合）
    min_samples_leaf=10,  # 叶节点最小样本数（默认1，增大增强泛化）
    max_features=0.8,  # 构建每棵树的最大特征比例
    random_state=42,  # 固定随机种子
    n_jobs=-1  # 并行计算（使用所有CPU核心）
)

# 训练
rf_model.fit(X_train, y_train)

# 预测（代码不变）
y_train_pred_rf = rf_model.predict(X_train)
y_test_pred_rf = rf_model.predict(X_test)

# 评估（代码不变）
# plot_analysis(rf_model, X_train, y_train, y_train_pred_rf, X_train.columns)
# plot_analysis(rf_model, X_test, y_test, y_test_pred_rf, X_test.columns)
train_metrics_rf = calculate_metrics(y_train, y_train_pred_rf)
test_metrics_rf = calculate_metrics(y_test, y_test_pred_rf)

print_metrics(train_metrics_rf, "随机森林-训练集")
print_metrics(test_metrics_rf, "随机森林-测试集")

results['随机森林'] = {
    'model': rf_model,
    'train_pred': y_train_pred_rf,
    'test_pred': y_test_pred_rf,
    'train_metrics': train_metrics_rf,
    'test_metrics': test_metrics_rf
}

# 4、XGBoost回归模型
xgb_model = xgb.XGBRegressor(
    objective='reg:squarederror',
    max_depth=3,
    min_child_weight=5,
    reg_alpha=15,
    reg_lambda=15,
    subsample=0.9,
    colsample_bytree=0.9,
    learning_rate=0.04,
    n_estimators=350,
    random_state=42,
    n_jobs=-1
)
# 训练
xgb_model.fit(X_train, y_train)
# 预测
y_train_pred_xgb = xgb_model.predict(X_train)
y_test_pred_xgb = xgb_model.predict(X_test)
# 评估
train_metrics_xgb = calculate_metrics(y_train, y_train_pred_xgb)
test_metrics_xgb = calculate_metrics(y_test, y_test_pred_xgb)
print_metrics(train_metrics_xgb, "XGBoost-训练集")
print_metrics(test_metrics_xgb, "XGBoost-测试集")

results['XGBoost'] = {
    'model': xgb_model,
    'train_pred': y_train_pred_xgb,
    'test_pred': y_test_pred_xgb,
    'train_metrics': train_metrics_xgb,
    'test_metrics': test_metrics_xgb
}

# 5、LightGBM模型
print("=" * 50)
print("训练LightGBM模型...")
lgb_model = lgb.LGBMRegressor(
    # 核心参数
    n_estimators=400,  # 更多迭代次数
    max_depth=9,  # 进一步降低树深度，控制过拟合
    learning_rate=0.01,  # 精细学习率
    num_leaves=30,  # 叶子数 < 2^max_depth (2^7=128)，更保守
    subsample=0.8,  # 样本采样率
    colsample_bytree=0.85,  # 特征采样率
    # 正则化
    reg_alpha=15,  # 轻微L1正则，防止过拟合
    reg_lambda=15,  # 轻微L2正则
    # 防止过拟合关键参数
    min_child_samples=30,  # 叶子节点最小样本数
    min_child_weight=1,  # 叶子节点最小权重和
    min_split_gain=2,  # 分裂最小增益，过滤无效分裂
    # Bagging策略
    bagging_fraction=0.85,  # 同subsample，可搭配bagging_freq
    bagging_freq=5,  # 每5轮迭代进行一次bagging
    random_state=42,
    n_jobs=-1
)
lgb_model.fit(
    X_train, y_train,
    eval_set=[(X_test, y_test)],
    eval_metric=['rmse', 'mae', 'mape', 'smape'],
)
# 预测
y_train_pred_lgb = lgb_model.predict(X_train)
y_test_pred_lgb = lgb_model.predict(X_test)

# 评估
train_metrics_lgb = calculate_metrics(y_train, y_train_pred_lgb)
test_metrics_lgb = calculate_metrics(y_test, y_test_pred_lgb)
print_metrics(train_metrics_lgb, "LightGBM-训练集")
print_metrics(test_metrics_lgb, "LightGBM-测试集")

results['LightGBM'] = {
    'model': lgb_model,
    'train_pred': y_train_pred_lgb,
    'test_pred': y_test_pred_lgb,
    'train_metrics': train_metrics_lgb,
    'test_metrics': test_metrics_lgb
}

# 6、深度神经网络模型
print("=" * 50)
print("训练深度神经网络模型...")

scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)
# 定义神经网络架构
def create_dnn_model():
    model = keras.Sequential([
        layers.Input(shape=(X_train_scaled.shape[1],)),
        layers.Dense(128, activation='relu'),
        layers.BatchNormalization(),
        layers.Dropout(0.3),
        layers.Dense(64, activation='relu'),
        layers.BatchNormalization(),
        layers.Dropout(0.2),
        layers.Dense(32, activation='relu'),
        layers.BatchNormalization(),
        layers.Dropout(0.1),
        layers.Dense(1)
    ])

    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=0.01),
        loss='mse',
        metrics=['mae', 'mse', tf.keras.metrics.R2Score()]
    )
    return model

# 创建模型
dnn_model = create_dnn_model()

# 设置回调函数
callbacks_list = [
    callbacks.EarlyStopping(
        monitor='val_loss',
        patience=60,
        restore_best_weights=True
    ),
    callbacks.ReduceLROnPlateau(
        monitor='val_loss',
        factor=0.5,
        patience=50,
        min_lr=1e-6
    )
]

# 训练模型
history = dnn_model.fit(
    X_train_scaled, y_train,
    validation_split=0.15,
    epochs=500,
    batch_size=32,
    callbacks=callbacks_list,
    verbose=1
)

# 预测
y_train_pred_dnn = dnn_model.predict(X_train_scaled).flatten()
y_test_pred_dnn = dnn_model.predict(X_test_scaled).flatten()

# 评估
train_metrics_dnn = calculate_metrics(y_train, y_train_pred_dnn)
test_metrics_dnn = calculate_metrics(y_test, y_test_pred_dnn)

print_metrics(train_metrics_dnn, "深度神经网络-训练集")
print_metrics(test_metrics_dnn, "深度神经网络-测试集")

results['深度神经网络'] = {
    'model': dnn_model,
    'train_pred': y_train_pred_dnn,
    'test_pred': y_test_pred_dnn,
    'train_metrics': train_metrics_dnn,
    'test_metrics': test_metrics_dnn,
    'history': history
}

# 7. 创建结果对比表格
print("\n" + "=" * 80)
print("多种模型性能对比总结")
print("=" * 80)

comparison_data = []
for model_name, result in results.items():
    train_metrics = result['train_metrics']
    test_metrics = result['test_metrics']

    comparison_data.append({
        '模型': model_name,
        '训练_RMSE': train_metrics['RMSE'],
        '训练_MAPE': train_metrics['MAPE'],
        '训练_R2': train_metrics['R2'],
        '测试_RMSE': test_metrics['RMSE'],
        '测试_MAPE': test_metrics['MAPE'],
        '测试_R2': test_metrics['R2'],
        '测试_SMAPE': test_metrics['SMAPE']
    })

comparison_df = pd.DataFrame(comparison_data)
print(comparison_df.round(4))

# 8. 绘制并保存性能对比图
models = list(results.keys())
# 基础指标变量
train_rmse = [results[model]['train_metrics']['RMSE'] for model in models]
test_rmse = [results[model]['test_metrics']['RMSE'] for model in models]
train_mape = [results[model]['train_metrics']['MAPE'] for model in models]
test_mape = [results[model]['test_metrics']['MAPE'] for model in models]
# 新增MSE和SMAPE变量
train_mse = [results[model]['train_metrics']['MSE'] for model in models]
test_mse = [results[model]['test_metrics']['MSE'] for model in models]
train_smape = [results[model]['train_metrics']['SMAPE'] for model in models]
test_smape = [results[model]['test_metrics']['SMAPE'] for model in models]

x = np.arange(len(models))
width = 0.35

# 8.1 RMSE对比图
plt.figure(figsize=(12, 6))
plt.bar(x - width / 2, train_rmse, width, label='训练集RMSE', alpha=0.7, color='skyblue')
plt.bar(x + width / 2, test_rmse, width, label='测试集RMSE', alpha=0.7, color='lightcoral')
plt.title('RMSE对比 - 多种回归模型', fontsize=14, fontweight='bold')
plt.xlabel('模型')
plt.ylabel('RMSE')
plt.xticks(x, models, rotation=45, ha='right')
plt.legend()
plt.grid(axis='y', alpha=0.3)

# 在柱子上添加数值标签
for i, v in enumerate(train_rmse):
    plt.text(i - width / 2, v + max(train_rmse) * 0.01, f'{v:.2f}',
             ha='center', va='bottom', fontsize=8, rotation=90)
for i, v in enumerate(test_rmse):
    plt.text(i + width / 2, v + max(test_rmse) * 0.01, f'{v:.2f}',
             ha='center', va='bottom', fontsize=8, rotation=90)

plt.tight_layout()
plt.savefig('多种模型_RMSE对比图.png', dpi=300, bbox_inches='tight')
plt.show()

# 8.2 MAPE对比图
plt.figure(figsize=(12, 6))
plt.bar(x - width / 2, train_mape, width, label='训练集MAPE', alpha=0.7, color='lightgreen')
plt.bar(x + width / 2, test_mape, width, label='测试集MAPE', alpha=0.7, color='orange')
plt.title('MAPE对比 - 多种回归模型', fontsize=14, fontweight='bold')
plt.xlabel('模型')
plt.ylabel('MAPE (%)')
plt.xticks(x, models, rotation=45, ha='right')
plt.legend()
plt.grid(axis='y', alpha=0.3)

# 在柱子上添加数值标签
for i, v in enumerate(train_mape):
    plt.text(i - width / 2, v + max(train_mape) * 0.01, f'{v:.2f}%',
             ha='center', va='bottom', fontsize=8, rotation=90)
for i, v in enumerate(test_mape):
    plt.text(i + width / 2, v + max(test_mape) * 0.01, f'{v:.2f}%',
             ha='center', va='bottom', fontsize=8, rotation=90)

plt.tight_layout()
plt.savefig('多种模型_MAPE对比图.png', dpi=300, bbox_inches='tight')
plt.show()

# 8.3 MSE对比图（新增）
plt.figure(figsize=(12, 6))
plt.bar(x - width / 2, train_mse, width, label='训练集MSE', alpha=0.7, color='lightseagreen')
plt.bar(x + width / 2, test_mse, width, label='测试集MSE', alpha=0.7, color='indianred')
plt.title('MSE对比 - 多种回归模型', fontsize=14, fontweight='bold')
plt.xlabel('模型')
plt.ylabel('MSE')
plt.xticks(x, models, rotation=45, ha='right')
plt.legend()
plt.grid(axis='y', alpha=0.3)

# 在柱子上添加数值标签
for i, v in enumerate(train_mse):
    plt.text(i - width / 2, v + max(train_mse) * 0.01, f'{v:.2f}',
             ha='center', va='bottom', fontsize=8, rotation=90)
for i, v in enumerate(test_mse):
    plt.text(i + width / 2, v + max(test_mse) * 0.01, f'{v:.2f}',
             ha='center', va='bottom', fontsize=8, rotation=90)

plt.tight_layout()
plt.savefig('多种模型_MSE对比图.png', dpi=300, bbox_inches='tight')
plt.show()

# 8.4 SMAPE对比图（新增）
plt.figure(figsize=(12, 6))
plt.bar(x - width / 2, train_smape, width, label='训练集SMAPE', alpha=0.7, color='mediumpurple')
plt.bar(x + width / 2, test_smape, width, label='测试集SMAPE', alpha=0.7, color='orangered')
plt.title('SMAPE对比 - 多种回归模型', fontsize=14, fontweight='bold')
plt.xlabel('模型')
plt.ylabel('SMAPE (%)')
plt.xticks(x, models, rotation=45, ha='right')
plt.legend()
plt.grid(axis='y', alpha=0.3)

# 在柱子上添加数值标签
for i, v in enumerate(train_smape):
    plt.text(i - width / 2, v + max(train_smape) * 0.01, f'{v:.2f}%',
             ha='center', va='bottom', fontsize=8, rotation=90)
for i, v in enumerate(test_smape):
    plt.text(i + width / 2, v + max(test_smape) * 0.01, f'{v:.2f}%',
             ha='center', va='bottom', fontsize=8, rotation=90)

plt.tight_layout()
plt.savefig('多种模型_SMAPE对比图.png', dpi=300, bbox_inches='tight')
plt.show()

# 8.5 综合评估指标对比图（2x2组合：RMSE、MAPE、MSE、SMAPE）（新增）
fig, axes = plt.subplots(2, 2, figsize=(16, 12))
fig.suptitle('模型综合评估指标对比', fontsize=18, fontweight='bold')

# 子图1：RMSE对比
axes[0, 0].bar(x - width/2, train_rmse, width, label='训练集', alpha=0.7, color='skyblue')
axes[0, 0].bar(x + width/2, test_rmse, width, label='测试集', alpha=0.7, color='lightcoral')
axes[0, 0].set_title('RMSE对比', fontsize=14, fontweight='bold')
axes[0, 0].set_xlabel('模型')
axes[0, 0].set_ylabel('RMSE (元/㎡)')
axes[0, 0].set_xticks(x)
axes[0, 0].set_xticklabels(models, rotation=45, ha='right')
axes[0, 0].legend()
axes[0, 0].grid(axis='y', alpha=0.3)
# 添加数值标签
for i, v in enumerate(train_rmse):
    axes[0, 0].text(i - width/2, v + max(train_rmse)*0.01, f'{v:.2f}', ha='center', va='bottom', fontsize=8)
for i, v in enumerate(test_rmse):
    axes[0, 0].text(i + width/2, v + max(test_rmse)*0.01, f'{v:.2f}', ha='center', va='bottom', fontsize=8)

# 子图2：MAPE对比
axes[0, 1].bar(x - width/2, train_mape, width, label='训练集', alpha=0.7, color='lightgreen')
axes[0, 1].bar(x + width/2, test_mape, width, label='测试集', alpha=0.7, color='orange')
axes[0, 1].set_title('MAPE对比', fontsize=14, fontweight='bold')
axes[0, 1].set_xlabel('模型')
axes[0, 1].set_ylabel('MAPE (%)')
axes[0, 1].set_xticks(x)
axes[0, 1].set_xticklabels(models, rotation=45, ha='right')
axes[0, 1].legend()
axes[0, 1].grid(axis='y', alpha=0.3)
# 添加数值标签
for i, v in enumerate(train_mape):
    axes[0, 1].text(i - width/2, v + max(train_mape)*0.01, f'{v:.2f}%', ha='center', va='bottom', fontsize=8)
for i, v in enumerate(test_mape):
    axes[0, 1].text(i + width/2, v + max(test_mape)*0.01, f'{v:.2f}%', ha='center', va='bottom', fontsize=8)

# 子图3：MSE对比
axes[1, 0].bar(x - width/2, train_mse, width, label='训练集', alpha=0.7, color='lightseagreen')
axes[1, 0].bar(x + width/2, test_mse, width, label='测试集', alpha=0.7, color='indianred')
axes[1, 0].set_title('MSE对比', fontsize=14, fontweight='bold')
axes[1, 0].set_xlabel('模型')
axes[1, 0].set_ylabel('MSE')
axes[1, 0].set_xticks(x)
axes[1, 0].set_xticklabels(models, rotation=45, ha='right')
axes[1, 0].legend()
axes[1, 0].grid(axis='y', alpha=0.3)
# 添加数值标签
for i, v in enumerate(train_mse):
    axes[1, 0].text(i - width/2, v + max(train_mse)*0.01, f'{v:.2f}', ha='center', va='bottom', fontsize=8)
for i, v in enumerate(test_mse):
    axes[1, 0].text(i + width/2, v + max(test_mse)*0.01, f'{v:.2f}', ha='center', va='bottom', fontsize=8)

# 子图4：SMAPE对比
axes[1, 1].bar(x - width/2, train_smape, width, label='训练集', alpha=0.7, color='mediumpurple')
axes[1, 1].bar(x + width/2, test_smape, width, label='测试集', alpha=0.7, color='orangered')
axes[1, 1].set_title('SMAPE对比', fontsize=14, fontweight='bold')
axes[1, 1].set_xlabel('模型')
axes[1, 1].set_ylabel('SMAPE (%)')
axes[1, 1].set_xticks(x)
axes[1, 1].set_xticklabels(models, rotation=45, ha='right')
axes[1, 1].legend()
axes[1, 1].grid(axis='y', alpha=0.3)
# 添加数值标签
for i, v in enumerate(train_smape):
    axes[1, 1].text(i - width/2, v + max(train_smape)*0.01, f'{v:.2f}%', ha='center', va='bottom', fontsize=8)
for i, v in enumerate(test_smape):
    axes[1, 1].text(i + width/2, v + max(test_smape)*0.01, f'{v:.2f}%', ha='center', va='bottom', fontsize=8)

plt.tight_layout()
plt.savefig('模型综合评估指标对比图.png', dpi=300, bbox_inches='tight')
plt.show()

# 8.6 特征重要性对比图（原8.4）
fig, axes = plt.subplots(3, 2, figsize=(15, 12))
fig.suptitle('不同模型的特征重要性对比', fontsize=16, fontweight='bold')

# 随机森林特征重要性
feature_importance_rf = rf_model.feature_importances_
importance_df_rf = pd.DataFrame({
    '特征': feature_columns,
    '重要性': feature_importance_rf
}).sort_values('重要性', ascending=True)

axes[0, 0].barh(importance_df_rf['特征'], importance_df_rf['重要性'], color='steelblue')
axes[0, 0].set_title('随机森林特征重要性')
axes[0, 0].set_xlabel('重要性得分')
axes[0, 0].grid(axis='x', alpha=0.3)

# XGBoost特征重要性
feature_importance_xgb = xgb_model.feature_importances_
importance_df_xgb = pd.DataFrame({
    '特征': feature_columns,
    '重要性': feature_importance_xgb
}).sort_values('重要性', ascending=True)

axes[0, 1].barh(importance_df_xgb['特征'], importance_df_xgb['重要性'], color='darkorange')
axes[0, 1].set_title('XGBoost特征重要性')
axes[0, 1].set_xlabel('重要性得分')
axes[0, 1].grid(axis='x', alpha=0.3)

# LightGBM特征重要性
feature_importance_lgb = lgb_model.feature_importances_
importance_df_lgb = pd.DataFrame({
    '特征': feature_columns,
    '重要性': feature_importance_lgb
}).sort_values('重要性', ascending=True)

axes[1, 0].barh(importance_df_lgb['特征'], importance_df_lgb['重要性'], color='forestgreen')
axes[1, 0].set_title('LightGBM特征重要性')
axes[1, 0].set_xlabel('重要性得分')
axes[1, 0].grid(axis='x', alpha=0.3)

# 线性回归系数重要性（绝对值）
coef_lr = np.abs(lr_model.coef_)
importance_df_lr = pd.DataFrame({
    '特征': feature_columns,
    '重要性': coef_lr
}).sort_values('重要性', ascending=True)

axes[1, 1].barh(importance_df_lr['特征'], importance_df_lr['重要性'], color='crimson')
axes[1, 1].set_title('线性回归系数重要性（绝对值）')
axes[1, 1].set_xlabel('重要性得分')
axes[1, 1].grid(axis='x', alpha=0.3)

# 综合特征重要性（平均）
importance_avg = (feature_importance_rf + feature_importance_xgb + feature_importance_lgb) / 3
importance_df_avg = pd.DataFrame({
    '特征': feature_columns,
    '重要性': importance_avg
}).sort_values('重要性', ascending=True)

axes[2, 0].barh(importance_df_avg['特征'], importance_df_avg['重要性'], color='darkviolet')
axes[2, 0].set_title('综合特征重要性（平均）')
axes[2, 0].set_xlabel('重要性得分')
axes[2, 0].grid(axis='x', alpha=0.3)

# 隐藏最后一个子图
axes[2, 1].axis('off')

plt.tight_layout()
plt.savefig('多种模型_特征重要性对比图.png', dpi=300, bbox_inches='tight')
plt.show()

# 8.7 DNN训练历史（原8.5）
if '深度神经网络' in results:
    history = results['深度神经网络']['history']
    fig, axes = plt.subplots(1, 2, figsize=(12, 4))

    axes[0].plot(history.history['loss'], label='训练损失')
    axes[0].plot(history.history['val_loss'], label='验证损失')
    axes[0].set_title('DNN训练损失曲线')
    axes[0].set_xlabel('轮次')
    axes[0].set_ylabel('损失')
    axes[0].legend()
    axes[0].grid(alpha=0.3)

    axes[1].plot(history.history['mae'], label='训练MAE')
    axes[1].plot(history.history['val_mae'], label='验证MAE')
    axes[1].set_title('DNN训练MAE曲线')
    axes[1].set_xlabel('轮次')
    axes[1].set_ylabel('MAE')
    axes[1].legend()
    axes[1].grid(alpha=0.3)

    plt.tight_layout()
    plt.savefig('深度神经网络训练曲线.png', dpi=300, bbox_inches='tight')
    plt.show()

# 8.8 模型预测效果可视化（原8.6）
fig, axes = plt.subplots(2, 3, figsize=(15, 10))
fig.suptitle('模型预测效果对比图', fontsize=16, fontweight='bold')

# 实际vs预测散点图
scatter_models = list(results.keys())
scatter_colors = ['red', 'blue', 'green', 'orange', 'purple', 'brown']

for idx, (model_name, color) in enumerate(zip(scatter_models, scatter_colors)):
    row = idx // 3
    col = idx % 3
    if row < 2 and col < 3:
        y_pred = results[model_name]['test_pred']

        axes[row, col].scatter(y_test, y_pred, alpha=0.5, color=color, s=20)
        axes[row, col].plot([y_test.min(), y_test.max()], [y_test.min(), y_test.max()],
                            'k--', lw=2, label='完美预测线')
        axes[row, col].set_xlabel('实际单价')
        axes[row, col].set_ylabel('预测单价')
        axes[row, col].set_title(f'{model_name}预测效果')
        axes[row, col].grid(alpha=0.3)
        axes[row, col].legend()

plt.tight_layout()
plt.savefig('多种模型_预测效果散点图.png', dpi=300, bbox_inches='tight')
plt.show()

# 9. 模型排名分析
print("\n" + "=" * 80)
print("模型性能排名")
print("=" * 80)

# 按测试集RMSE排序
test_rmse_ranking = sorted([(model, results[model]['test_metrics']['RMSE'])
                            for model in models], key=lambda x: x[1])

print("\n测试集RMSE排名（从优到劣）:")
for i, (model, rmse) in enumerate(test_rmse_ranking, 1):
    print(f"{i}. {model}: {rmse:.2f}")

# 按测试集MAPE排序
test_mape_ranking = sorted([(model, results[model]['test_metrics']['MAPE'])
                            for model in models], key=lambda x: x[1])

print("\n测试集MAPE排名（从优到劣）:")
for i, (model, mape) in enumerate(test_mape_ranking, 1):
    print(f"{i}. {model}: {mape:.2f}%")

# 按测试集R²排序
test_r2_ranking = sorted([(model, results[model]['test_metrics']['R2'])
                          for model in models], key=lambda x: x[1], reverse=True)

print("\n测试集R²排名（从优到劣）:")
for i, (model, r2) in enumerate(test_r2_ranking, 1):
    print(f"{i}. {model}: {r2:.4f}")

# 新增：按MSE和SMAPE排序
test_mse_ranking = sorted([(model, results[model]['test_metrics']['MSE'])
                            for model in models], key=lambda x: x[1])
print("\n测试集MSE排名（从优到劣）:")
for i, (model, mse) in enumerate(test_mse_ranking, 1):
    print(f"{i}. {model}: {mse:.2f}")

test_smape_ranking = sorted([(model, results[model]['test_metrics']['SMAPE'])
                            for model in models], key=lambda x: x[1])
print("\n测试集SMAPE排名（从优到劣）:")
for i, (model, smape) in enumerate(test_smape_ranking, 1):
    print(f"{i}. {model}: {smape:.2f}%")

# 10. 保存预测结果
predictions_df = pd.DataFrame({
    '实际单价': y_test.values,
})

# 添加各个模型的预测结果
for model_name in results.keys():
    predictions_df[f'{model_name}预测'] = results[model_name]['test_pred']
    predictions_df[f'{model_name}误差'] = predictions_df['实际单价'] - predictions_df[f'{model_name}预测']
    predictions_df[f'{model_name}相对误差(%)'] = np.abs(
        predictions_df[f'{model_name}误差'] / predictions_df['实际单价']) * 100

# 添加特征数据
for i, col in enumerate(feature_columns):
    predictions_df[col] = X_test.iloc[:, i].values

predictions_df.to_excel('多种模型预测结果.xlsx', index=False)

# 11. 输出最佳模型
best_model_rmse = min(results.keys(), key=lambda x: results[x]['test_metrics']['RMSE'])
best_rmse = results[best_model_rmse]['test_metrics']['RMSE']
best_mape_rmse = results[best_model_rmse]['test_metrics']['MAPE']
best_r2_rmse = results[best_model_rmse]['test_metrics']['R2']

best_model_mape = min(results.keys(), key=lambda x: results[x]['test_metrics']['MAPE'])
best_mape = results[best_model_mape]['test_metrics']['MAPE']
best_rmse_mape = results[best_model_mape]['test_metrics']['RMSE']
best_r2_mape = results[best_model_mape]['test_metrics']['R2']

best_model_r2 = max(results.keys(), key=lambda x: results[x]['test_metrics']['R2'])
best_r2 = results[best_model_r2]['test_metrics']['R2']
best_rmse_r2 = results[best_model_r2]['test_metrics']['RMSE']
best_mape_r2 = results[best_model_r2]['test_metrics']['MAPE']

# 新增：基于MSE和SMAPE的最佳模型
best_model_mse = min(results.keys(), key=lambda x: results[x]['test_metrics']['MSE'])
best_mse = results[best_model_mse]['test_metrics']['MSE']
best_smape_mse = results[best_model_mse]['test_metrics']['SMAPE']

best_model_smape = min(results.keys(), key=lambda x: results[x]['test_metrics']['SMAPE'])
best_smape = results[best_model_smape]['test_metrics']['SMAPE']
best_mse_smape = results[best_model_smape]['test_metrics']['MSE']

print("\n" + "=" * 80)
print("最佳模型分析")
print("=" * 80)

print(f"\n 基于RMSE的最佳模型: {best_model_rmse}")
print(f"  最佳RMSE: {best_rmse:.2f}")
print(f"  对应MAPE: {best_mape_rmse:.2f}%")
print(f"  对应R²: {best_r2_rmse:.4f}")

print(f"\n 基于MAPE的最佳模型: {best_model_mape}")
print(f"  最佳MAPE: {best_mape:.2f}%")
print(f"  对应RMSE: {best_rmse_mape:.2f}")
print(f"  对应R²: {best_r2_mape:.4f}")

print(f"\n 基于R²的最佳模型: {best_model_r2}")
print(f"  最佳R²: {best_r2:.4f}")
print(f"  对应RMSE: {best_rmse_r2:.2f}")
print(f"  对应MAPE: {best_mape_r2:.2f}%")

print(f"\n 基于MSE的最佳模型: {best_model_mse}")
print(f"  最佳MSE: {best_mse:.2f}")
print(f"  对应SMAPE: {best_smape_mse:.2f}%")

print(f"\n 基于SMAPE的最佳模型: {best_model_smape}")
print(f"  最佳SMAPE: {best_smape:.2f}%")
print(f"  对应MSE: {best_mse_smape:.2f}")

# 与随机森林的性能对比
rf_test_rmse = results['随机森林']['test_metrics']['RMSE']
rf_test_mape = results['随机森林']['test_metrics']['MAPE']
rf_test_r2 = results['随机森林']['test_metrics']['R2']
rf_test_mse = results['随机森林']['test_metrics']['MSE']
rf_test_smape = results['随机森林']['test_metrics']['SMAPE']

print(f"\n" + "=" * 80)
print("相对于随机森林的性能提升")
print("=" * 80)

for model_name in results.keys():
    if model_name != '随机森林':
        model_rmse = results[model_name]['test_metrics']['RMSE']
        model_mape = results[model_name]['test_metrics']['MAPE']
        model_r2 = results[model_name]['test_metrics']['R2']
        model_mse = results[model_name]['test_metrics']['MSE']
        model_smape = results[model_name]['test_metrics']['SMAPE']

        rmse_improvement = ((rf_test_rmse - model_rmse) / rf_test_rmse) * 100
        mape_improvement = ((rf_test_mape - model_mape) / rf_test_mape) * 100
        r2_improvement = ((model_r2 - rf_test_r2) / (1 - rf_test_r2)) * 100
        mse_improvement = ((rf_test_mse - model_mse) / rf_test_mse) * 100
        smape_improvement = ((rf_test_smape - model_smape) / rf_test_smape) * 100

        print(f"\n{model_name} 对比 随机森林:")
        print(f"  RMSE提升: {rmse_improvement:.2f}% ({rf_test_rmse:.2f} → {model_rmse:.2f})")
        print(f"  MAPE提升: {mape_improvement:.2f}% ({rf_test_mape:.2f}% → {model_mape:.2f}%)")
        print(f"  R²提升: {r2_improvement:.2f}% ({rf_test_r2:.4f} → {model_r2:.4f})")
        print(f"  MSE提升: {mse_improvement:.2f}% ({rf_test_mse:.2f} → {model_mse:.2f})")
        print(f"  SMAPE提升: {smape_improvement:.2f}% ({rf_test_smape:.2f}% → {model_smape:.2f}%)")

# 保存模型性能总结
summary_df = pd.DataFrame(comparison_data)
summary_df.to_excel('多种模型性能总结.xlsx', index=False)