defmodule Master do
    def init(lista1, lista2, lista3) do
        numProcesos = (length(lista1) + length(lista2) + length(lista3))/3
        receive do
            {pid, listaNumeros} ->
                result = loop(lista1, lista2, lista3, numProcesos, listaNumeros, [])
                send pid, {result}
                init(lista1, lista2, lista3)
        end
    end
    
    def funcion(pid, nodo1, nodo2, nodo3, n) do
        send nodo2, {:req, self(), n}
        IO.puts IO.ANSI.format([:yellow, "Petición a un worker del tipo 2"])
        receive do
            {result} ->
                IO.puts IO.ANSI.format([:green, "Obtenido el resultado por parte del worker de tipo 2"])
                send pid, {:success, result, n, nodo1, nodo2, nodo3} 
        after
            200 ->
                IO.puts IO.ANSI.format([:red, "El worker de tipo 2 no ha respondido"])
                send nodo1, {:req, self(), n}
                IO.puts IO.ANSI.format([:yellow, "Petición a un worker del tipo 1"])
                receive do
                    {result1} ->
                        IO.puts IO.ANSI.format([:green, "Se obtiene resultado del worker 1"])
                        IO.puts IO.ANSI.format([:yellow, "Se hace petición a un worker de tipo 3"])
                        send nodo3, {:req, self(), result1}
                        receive do
                            {result3} ->
                                IO.puts IO.ANSI.format([:green, "Obtenido el resultado por parte del worker de tipo 3"])
                                send pid, {:success, result3, n, nodo1, nodo2, nodo3} 
                        after
                            200 ->
                                IO.puts IO.ANSI.format([:red, "El worker de tipo 3 no ha respondido"])
                                send pid, {:timeout, n, nodo1, nodo2, nodo3}
                        end
                after
                    200 -> 
                        IO.puts IO.ANSI.format([:red, "El worker de tipo 1 no ha respondido"])
                        send pid, {:timeout, n, nodo1, nodo2, nodo3}
                end
        end
    end
    
    def loop(lista1, lista2, lista3, numProcesos, listaNumeros, listaResultados) do
        if(numProcesos == 0) do
            receive do
                {:timeout, n, nodo1, nodo2, nodo3} ->
                    loop(lista1 ++ [nodo1], lista2 ++ [nodo2], lista3 ++ [nodo3], numProcesos + 1, [n] ++ listaNumeros, listaResultados)
                {:success, result, n, nodo1, nodo2, nodo3} ->
                    if (result == n) do
                        loop(lista1 ++ [nodo1], lista2 ++ [nodo2], lista3 ++ [nodo3], numProcesos + 1, listaNumeros, listaResultados ++ [result])
                    else
                        loop(lista1 ++ [nodo1], lista2 ++ [nodo2], lista3 ++ [nodo3], numProcesos + 1, listaNumeros, listaResultados)
                    end
            end
        else
            spawn(fn->funcion(self(), hd(lista1), hd(lista2), hd(lista3), hd(listaNumeros))end)
            loop(tl(lista1), tl(lista2), tl(lista3), numProcesos - 1, tl(listaNumeros), listaResultados)
        end
    end
end
