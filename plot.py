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
    def plot(df: pd.DataFrame, algo: str) -> None:
      fig, axes = plt.subplots(4, 4, figsize=(24, 24))

      d = df.query('bin_size > 8')

      for ax, size in zip(axes.flatten(), sorted(d['bin_size'].unique())):
        dd = d[(d['name'] == algo) & (d['bin_size'] == size)]
        sns.histplot(data=dd, x='cpu_time', ax=ax)
        ax.set_title(f'tamanho = {2**size} | Sample = {dd.shape[0]}')

        for ext in PLOT_EXTS:
            path = os.path.join(OUT_ROOT, algo)
            os.makedirs(path, exist_ok=True)
            fig.savefig(os.path.join(path, f'hist.{ext}'), dpi=300)

    for algo in df['name'].unique():
        plot(df, algo)

def plot_lines(df: pd.DataFrame, name: str) -> None:
    fig, axes = plt.subplots(1, 2, figsize=(24, 12))

    for ax, y in zip(axes, ['real_time', 'cpu_time']):
        sns.lineplot(data=df, x='bin_size', y=y, hue='name', ax=ax)
        ax.xaxis.set_major_locator(ticker.MultipleLocator(2))
        ax.xaxis.set_minor_locator(ticker.MultipleLocator(1))
        ax.xaxis.set_major_formatter(ticker.FuncFormatter(lambda x,_: f"$2^{{{int(x)}}}$"))
        ax.yaxis.set_major_formatter(ticker.FuncFormatter(lambda x,_: f"${x/1e6}$"))
        ax.grid(True)
        ax.set_yscale('log')

        legend = ax.get_legend()
        legend.set_title("Algoritmo")

        ax.set_xlabel("Bin Size ($2^n$)")
        ax.set_ylabel(f"{y.replace('_', ' ').title()} (log scale)")


    for ext in PLOT_EXTS:
        path = os.path.join(OUT_ROOT, name)
        os.makedirs(path, exist_ok=True)
        fig.savefig(os.path.join(path, f'lineplot.{ext}'), dpi=300)

def boxplot_bench(df: pd.DataFrame, name: str) -> None:
    dist = df['bin_size'].unique().max() - df['bin_size'].unique().min()
    fig, axes = plt.subplots(8, 2, figsize=(24, 60))

    d = np.ceil(dist / len(axes.flatten()))

    for i, ax in enumerate(axes.flatten()):
      lb = df['bin_size'].unique().min() + d * (i)
      ub = lb + d
      dd = df[(df['bin_size'] >= lb )& (df['bin_size'] < ub)]


      dd['bin_size'] = dd['bin_size'].astype(int)
      sns.boxplot(data=dd, x='bin_size', y='real_time', hue='name', ax=ax)

      current_labels = [label.get_text() for label in ax.get_xticklabels()]
      new_labels = [f"$2^{{{label}}}$" for label in current_labels]
      ax.set_xticklabels(new_labels)
      ax.set_ylabel('Tempo de Execução (ms)')
      ax.set_xlabel('Tamanho da Entrada')
      legend = ax.get_legend()
      legend.set_title("Algoritmo")

    for ext in PLOT_EXTS:
        path = os.path.join(OUT_ROOT, name)
        os.makedirs(path, exist_ok=True)
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
    return fdf

def thread_boxplot(df: pd.DataFrame, name: str):
    pass


def plot_threads(root: str, name: str) -> None:
    df = pd.read_csv(os.path.join(root, name))
    name = name.removesuffix('.csv')

def plot_compares(root: str, name: str) -> None:
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
    print(f"\thist")
    histogram(fdf, name)





def main() -> None:
    for root, _, files in os.walk(DATA_ROOT):
        for csv in filter(lambda x: x.endswith('.csv'), files):
            if re.search(r"^\d+_\d+_\d+_\d+\.csv$", csv):
                plot_compares(root, csv)
            elif csv == 'threads.csv':
                plot_threads(root, csv)

if __name__ == '__main__':
    main()
