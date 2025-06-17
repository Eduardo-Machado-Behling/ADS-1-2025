#!./.venv/bin/python

import os
from io import StringIO
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import seaborn as sns
import re
import warnings
warnings.filterwarnings('ignore')

DATA_ROOT = os.path.join(os.getcwd(), "data")
OUT_ROOT = os.path.join(os.getcwd(), "plots")
PLOT_EXTS = ['pdf', 'png', 'jpeg']

def histogram(df: pd.DataFrame, algo: str) -> None:
    def plot(df: pd.DataFrame, algo: str):
      fig, axes = plt.subplots(4, 4, figsize=(24, 24))

      d = df.query('bin_size > 8')

      for ax, size in zip(axes.flatten(), sorted(d['bin_size'].unique())):
        dd = d[(d['name'] == algo) & (d['bin_size'] == size)]
        sns.histplot(data=dd, x='real_time_ms', ax=ax)
        ax.set_title(f'tamanho = $2^{{{size}}}$ [{dd.shape[0]} Amostras]')
        ax.set_xlabel('Tempo de Execução (ms)')
        ax.set_ylabel('Frequência')

      fig.suptitle(f'Distribuição do Tempo de Execução do algoritmo {algo}', fontsize=32, y=0.99)

      # Adjust layout to prevent titles from overlapping
      fig.tight_layout(rect=[0, 0.03, 1, 0.97])

      path = os.path.join(OUT_ROOT, algo)
      os.makedirs(path, exist_ok=True)
      for ext in PLOT_EXTS:
          fig.savefig(os.path.join(path, f'hist.{ext}'), dpi=300)

    for algo in df['name'].unique():
        print(f"\t\t{algo}")
        plot(df, algo)

def plot_lines(df: pd.DataFrame, name: str) -> None:
    fig, axes = plt.subplots(1, 2, figsize=(24, 12))

    for ax, y in zip(axes, ['real_time_ms', 'cpu_time_ms']):
        sns.lineplot(data=df, x='bin_size', y=y, hue='name', ax=ax)
        ax.xaxis.set_major_locator(ticker.MultipleLocator(2))
        ax.xaxis.set_minor_locator(ticker.MultipleLocator(1))
        ax.xaxis.set_major_formatter(ticker.FuncFormatter(lambda x,_: f"$2^{{{int(x)}}}$"))
        ax.yaxis.set_major_formatter(ticker.FuncFormatter(lambda x,_: f"${x/1e6}$"))
        ax.grid(True)
        ax.grid(True, which='minor', axis='x', linestyle='--')
        ax.set_yscale('log')

        legend = ax.get_legend()
        legend.set_title("Algoritmo")

        ax.set_xlabel("Tamanho da Entrada")
        ax.set_ylabel(f"{y.replace('_', ' ').title()[:-3]} (ms)")


    fig.tight_layout()
    path = os.path.join(OUT_ROOT, name)
    os.makedirs(path, exist_ok=True)
    for ext in PLOT_EXTS:
        fig.savefig(os.path.join(path, f'lineplot.{ext}'), dpi=300)

def boxplot_bench(df: pd.DataFrame, name: str) -> None:
    dist = df['bin_size'].unique().max() - df['bin_size'].unique().min()
    fig, axes = plt.subplots(8, 2, figsize=(24, 60))

    d = np.ceil(dist / len(axes.flatten()))

    for i, ax in enumerate(axes.flatten()):
      lb = df['bin_size'].unique().min() + d * (i)
      ub = lb + d
      dd = df[(df['bin_size'] >= lb )& (df['bin_size'] < ub)]


      if dd.empty:
          continue

      dd['bin_size'] = dd['bin_size'].astype(int)
      sns.boxplot(data=dd, x='bin_size', y='real_time_ms', hue='name', ax=ax)

      current_labels = [label.get_text() for label in ax.get_xticklabels()]
      new_labels = [f"$2^{{{label}}}$" for label in current_labels]
      ax.set_xticklabels(new_labels)
      ax.set_ylabel('Tempo de Execução (ms)')
      ax.set_xlabel('Tamanho da Entrada')
      legend = ax.get_legend()
      legend.set_title("Algoritmo")

    fig.tight_layout()
    path = os.path.join(OUT_ROOT, name)
    os.makedirs(path, exist_ok=True)
    for ext in PLOT_EXTS:
        fig.savefig(os.path.join(path, f'boxplot.{ext}'), dpi=300)

def bench_shapes(df: pd.DataFrame, name: str) -> None:
    def moment_2(series):
        return ((series - series.mean())**2).mean()

    def moment_3(series):
        return ((series - series.mean())**3).mean()

    def moment_4(series):
        return ((series - series.mean())**4).mean()

    def kurtosis_agg(series):
        m2 = moment_2(series)
        m4 = moment_4(series)
        if m2 == 0:  # Avoid division by zero
            return np.nan
        return m4 / (m2**2)

    def coef_assim_agg(series):
        m2 = moment_2(series)
        m3 = moment_3(series)
        if m2 == 0:  # Avoid division by zero
            return np.nan
        return m3 / (m2 * np.sqrt(m2))

    aggregated_df = df.groupby(['size', 'name'])['cpu_time'].agg(
        mean='mean',
        std='std',
        min='min',
        max='max',
        q25=lambda x: x.quantile(0.25),
        q50=lambda x: x.quantile(0.50),
        q75=lambda x: x.quantile(0.75),
        mode=lambda x: x.mode()[0] if not x.mode().empty else np.nan,
        kurtosis=kurtosis_agg,
        coef_assim=coef_assim_agg
    ).reset_index() # reset_index() to make 'size' a regular column for merging

    def class_kurt(x):
        labels = ['Platicurtica', 'Leptocurtica', 'Mesocurtica']
        if x > 3:
          return labels[0]
        elif x < -3:
          return labels[1]
        else:
          return labels[2]

    def class_symm(x):
        labels = ['Assim. Pos.', 'Assim. Neg.', 'Aprox. Sim.']
        if x > 0.5:
          return labels[0]
        elif x < -0.5:
          return labels[1]
        else:
          return labels[2]

    aggregated_df['kurtosis classification'] = aggregated_df['kurtosis'].apply(class_kurt)
    aggregated_df['symmetry classification'] = aggregated_df['coef_assim'].apply(class_symm)
    aggregated_df['cv'] = aggregated_df['std'] / aggregated_df['mean']
    aggregated_df['bin_size'] = aggregated_df['size'].apply(lambda x: int(np.log2(x))).astype(int)
    aggregated_df['classification'] = aggregated_df['symmetry classification'] + ' &\n' + aggregated_df['kurtosis classification']

    fig, ax = plt.subplots(figsize=(12, 15))

    ax.set_axisbelow(True)
    aggregated_df.sort_values(by='classification', ascending=False, inplace=True)
    sns.countplot(data=aggregated_df, x='classification', hue='name', ax=ax)
    ax.set_xlabel("Classificação")
    ax.set_ylabel("Quantidade")
    ax.grid(True, axis='y')
    ax.grid(True, axis='y', which='minor', linestyle='--')
    ax.yaxis.set_minor_locator(ticker.MultipleLocator(1))
    ax.get_legend().set_title('Algoritmo')
    ax.set_title("Formato da distribuição por Algoritmo")

    fig.tight_layout()
    path = os.path.join(OUT_ROOT, name)
    os.makedirs(path, exist_ok=True)
    aggregated_df.to_csv(os.path.join(path, 'metrics.csv'))
    for ext in PLOT_EXTS:
        fig.savefig(os.path.join(path, f'boxplot.{ext}'), dpi=300)

def preprocess_bench(df: pd.DataFrame) -> pd.DataFrame:
    names = {
        'BM_MergeSort': 'MergeSort (Weiss)',
        'BM_Qsort': 'QuickSort (C)',
        'BM_ParallelMergeSort': 'ParallelMergeSort (Original)',
        'BM_QuickSort': 'QuickSort (Cormen)',
        'BM_CPPSort': 'QuickSort (C++ standard)'
    }

    def filter(s: str) -> bool:
      mat = re.search(r'repeats:\d+$', s)
      return mat is not None


    fdf = df[df['name'].apply(filter)]
    fdf['size'] = fdf['name'].apply(lambda x: x.split('/')[1]).astype(int)
    fdf['bin_size'] = fdf['size'].apply(lambda x: int(np.log2(x)))
    fdf['repeats'] = fdf['name'].apply(lambda x: x.split('/')[2].split(":")[1]).astype(int)
    fdf['name'] = fdf['name'].apply(lambda x: names[x.split('/')[0]])
    fdf['cpu_time_ms'] = fdf['cpu_time'] / 1e6
    fdf['real_time_ms'] = fdf['real_time'] / 1e6
    return fdf

def thread_boxplot(df: pd.DataFrame, name: str):
    fig, ax = plt.subplots(figsize=(6*2, 6*2))

    sns.lineplot(data=df, x='bin_size', y='real_time_ms', hue='threads', ax=ax)
    ax.set_yscale('log')
    ax.grid(True, axis='y')
    ax.grid(True, axis='y', which='minor', linestyle='--')
    ax.set_ylabel("Tempo de Execução (ms)")
    ax.set_xlabel("Tamanho da Entrada")
    ax.get_legend().set_title('Quantidade de Threads')

    fig.tight_layout()
    path = os.path.join(OUT_ROOT, name)
    os.makedirs(path, exist_ok=True)
    for ext in PLOT_EXTS:
        fig.savefig(os.path.join(path, f'boxplot.{ext}'), dpi=300)


def plot_threads(root: str, name: str) -> None:
    df = preprocess_bench(pd.read_csv(os.path.join(root, name)))
    name = name.removesuffix('.csv')
    print(f"threading: {name}")
    thread_boxplot(df, name)


def plot_compares(root: str, name: str) -> pd.DataFrame:
    with open(os.path.join(root, name)) as csv:
        data = ''.join(filter(lambda s: re.search(r"^(\S+,)+.*\n$", s), csv.readlines()))
    
    df = pd.read_csv(StringIO(data))
    name = name.removesuffix('.csv')
    print(f"plotting {name}:")
    fdf = preprocess_bench(df)
    print(f"\tlines")
    plot_lines(fdf, name)
    print(f"\tboxplot")
    boxplot_bench(fdf, name)
    print("\tmetrics")
    bench_shapes(fdf, name)
    print(f"\thist")
    histogram(fdf, name)
    return fdf

def plot_data(root: str, name: str, fdf: pd.DataFrame, fdf_name: str) -> None:
    data = pd.read_csv(os.path.join(root, name))

    data['bin_size'] = data['size'].apply(lambda x: int(np.log2(x))).astype(int)
    data['real_time_ms'] = data['real_time'] / 1e6

    fig, axes = plt.subplots(1, 2, figsize=(24, 8))

    df = fdf[fdf['name'] == 'ParallelMergeSort (Original)']
    df['cpu_time_ms'] = df['cpu_time'] / 1_000_000
    df['real_time_ms'] = df['real_time'] / 1_000_000

    sns.lineplot(data=data, x='bin_size', y='real_time_ms', hue='arq', ax=axes[0])
    axes[0].set_title("Comparação com resultados usando a mesuração autoral:")
    axes[0].set_ylabel("Tempo de Execução (ms)")
    axes[0].set_xlabel("Tamanho do Vetor")
    axes[0].set_yscale("log")
    axes[0].xaxis.set_major_formatter(ticker.FuncFormatter(lambda x, _: f'$2^{{{int(x)}}}$'))
    axes[0].xaxis.set_minor_locator(ticker.MultipleLocator(1))
    axes[0].grid(True)
    axes[0].grid(True, which='minor', linestyle='--')

    d = data.groupby(['arq', 'bin_size'])['real_time_ms'].mean().reset_index().query('arq==23201209')
    fdf['real_time_ms'] = fdf['real_time'] / 1e6
    d1 = fdf.query("name=='ParallelMergeSort (Original)'").groupby(['bin_size'])['real_time_ms'].mean().reset_index()

    merged_df = pd.merge(d, d1, on='bin_size', how='left')

    merged_df = merged_df.rename(columns={'real_time_ms': 'bench'})

    merged_df['error'] = merged_df['bench'] - merged_df['real_time_ms']
    merged_df['error_cv'] = merged_df['error'] / merged_df['bench']

    sns.lineplot(data=merged_df, x='bin_size', y='error_cv', ax=axes[1])
    axes[1].set_title("Diferença Entre a mêdia Mesuração Autoral (32 Amostras) e a Mesuração Gbenchmark (200 Amostras):")
    axes[1].set_ylabel(r"Diferença sobre a mêdia gbench ($\frac{\bar{x}_{gbench}-\bar{x}_{autoral}}{\bar{x}_{gbench}}$)")
    axes[1].set_xlabel("Tamanho do Vetor")
    axes[1].set_xticks(sorted(d['bin_size'].unique())[::2])
    axes[1].xaxis.set_major_formatter(ticker.FuncFormatter(lambda x, _: f'$2^{{{int(x)}}}$'))
    axes[1].xaxis.set_minor_locator(ticker.MultipleLocator(1))
    axes[1].grid(True)
    axes[1].grid(True, which='minor', linestyle='--')
    fig.tight_layout()
    path = os.path.join(OUT_ROOT, name)
    os.makedirs(path, exist_ok=True)
    h = fdf_name
    for ext in PLOT_EXTS:
        fig.savefig(os.path.join(path, f'comp_{h}.{ext}'), dpi=300)




def main() -> None:
    for root, _, files in os.walk(DATA_ROOT):
        dfs = []
        for csv in sorted(filter(lambda x: x.endswith('.csv'), files), key=lambda x: -1 if x != 'data.csv' else 1):
            try:
                if re.search(r"^T?\d+_L?\d+_S?\d+_G?\d+\.csv$", csv):
                    dfs.append((plot_compares(root, csv), csv))
                elif csv == 'threads.csv':
                    plot_threads(root, csv)
                elif csv == 'data.csv':
                    print("data plotting:")
                    for i, (df, ndf) in enumerate(dfs):
                        print(f"\tdf #{i + 1}/{len(dfs)}")
                        plot_data(root, csv, df, ndf)
            except KeyboardInterrupt:
                continue

if __name__ == '__main__':
    main()
