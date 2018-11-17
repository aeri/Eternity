defmodule Master do
    def init(lista1, lista2, lista3) do
        numProcesos = (length(lista1) + length(lista2) + length(lista3))/3
        receive do
            {pid, listaNumeros} ->
                result = loop(lista1, lista2, lista3, numProcesos, listaNumeros, [])
        end
        send pid, {result}
        init(lista1, lista2, lista3)
    end
    
    def loop(lista1, lista2, lista3, numProcesos, listaNumeros, listaResultados) do
        if(numProcesos == 0) do
            receive do
                {:timeout, n, nodo1, nodo2, nodo3} ->
                    newnumProcesos = numProcesos + 1
                    newlista1 = lista1 ++ [nodo1]
                    newlista2 = lista2 ++ [nodo2]
                    newlista3 = lista3 ++ [nodo3]
                    newlistaNumeros = [n] ++ listaNumeros
                    loop(newlista1, newlista2, newlista3, newnumProcesos, newlistaNumeros, listaResultados)
                {:success, result, nodo1, nodo2, nodo3} ->
                    newnumProcesos = numProcesos + 1
                    newlista1 = lista1 ++ [nodo1]
                    newlista2 = lista2 ++ [nodo2]
                    newlista3 = lista3 ++ [nodo3]
                    newlistaResultados = listaResultados ++ [result]
                    loop(newlista1, newlista2, newlista3, newnumProcesos, listaNumeros, newlistaResultados)
            end
        else
    end
end
