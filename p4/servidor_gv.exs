require IEx # Para utilizar IEx.pry

defmodule ServidorGV do
    @moduledoc """
        modulo del servicio de vistas
    """

    # Tipo estructura de datos que guarda el estado del servidor de vistas
    # COMPLETAR  con lo campos necesarios para gestionar
    # el estado del gestor de vistas
    defstruct   num_vista: 0, 
                primario: :undefined,
                copia: :undefined

    # Constantes
    @latidos_fallidos 4

    @intervalo_latidos 50


    @doc """
        Acceso externo para constante de latidos fallios
    """
    def latidos_fallidos() do
        @latidos_fallidos
    end

    @doc """
        acceso externo para constante intervalo latido
    """
   def intervalo_latidos() do
       @intervalo_latidos
   end

   @doc """
        Generar un estructura de datos vista inicial
    """
    def vista_inicial() do
        %{num_vista: 0, primario: :undefined, copia: :undefined}
    end

    @doc """
        Poner en marcha el servidor para gestión de vistas
        Devolver atomo que referencia al nuevo nodo Elixir
    """
    @spec startNodo(String.t, String.t) :: node
    def startNodo(nombre, maquina) do
                                         # fichero en curso
        NodoRemoto.start(nombre, maquina, __ENV__.file)
    end

    @doc """
        Poner en marcha servicio trás esperar al pleno funcionamiento del nodo
    """
    @spec startService(node) :: boolean
    def startService(nodoElixir) do
        NodoRemoto.esperaNodoOperativo(nodoElixir, __MODULE__)
        
        # Poner en marcha el código del gestor de vistas
        Node.spawn(nodoElixir, __MODULE__, :init_sv, [])
   end

    #------------------- FUNCIONES PRIVADAS ----------------------------------

    # Estas 2 primeras deben ser defs para llamadas tipo (MODULE, funcion,[])
    def init_sv() do
        Process.register(self(), :servidor_gv)

        spawn(__MODULE__, :init_monitor, [self()]) # otro proceso concurrente

        #### VUESTRO CODIGO DE INICIALIZACION
        tentativa = vista_inicial() # Se crea una vista con primario y copia con valor undefined
        valida = vista_inicial() # Se crea una vista con primario y copia con valor undefined
        bucle_recepcion(tentativa, valida)
    end

    def init_monitor(pid_principal) do
        send(pid_principal, :procesa_situacion_servidores)
        Process.sleep(@intervalo_latidos)
        init_monitor(pid_principal)
    end


    defp bucle_recepcion(tentativa, valida) do
        {tentativa, valida} = receive do
                    {:latido, 0, nodo_emisor} ->
                        if tentativa.primario == :undefined do
                            tentativa = %{num_vista: tentativa.num_vista + 1, primario: nodo_emisor, copia: tentativa.copia}
                            send {:cliente_gv, nodo_emisor}, {:vista_tentativa, tentativa, tentativa==valida}
                            {tentativa, valida}
                        else 
                            if tentativa.copia == :undefined do
                                tentativa = %{num_vista: tentativa.num_vista + 1, primario: tentativa.primario, copia: nodo_emisor}
                                send {:cliente_gv, nodo_emisor}, {:vista_tentativa, tentativa, tentativa==valida}
                                {tentativa, valida}
                            else
                                if tentativa.primario == nodo_emisor do
                                    tentativa = %{num_vista: tentativa.num_vista + 1, primario: tentativa.copia, copia: :undefined}
                                    send {:cliente_gv, nodo_emisor}, {:vista_tentativa, tentativa, tentativa==valida}
                                    {tentativa, valida}
                                else
                                    if tentativa.copia == nodo_emisor do
                                        tentativa = %{num_vista: tentativa.num_vista + 1, primario: tentativa.primario, copia: :undefined}
                                        send {:cliente_gv, nodo_emisor}, {:vista_tentativa, tentativa, tentativa==valida}
                                        {tentativa, valida}
                                    else
                                        send {:cliente_gv, nodo_emisor}, {:vista_tentativa, tentativa, tentativa==valida}
                                        {tentativa, valida}
                                    end
                                end
                            end
                        end
                    {:latido, -1, nodo_emisor} ->
                        send {:cliente_gv, nodo_emisor}, {:vista_tentativa, tentativa, tentativa==valida}
                        {tentativa, valida}
                        
                    {:latido, n, nodo_emisor} ->
                        if nodo_emisor == tentativa.primario do
                            valida = tentativa
                            send {:cliente_gv, nodo_emisor}, {:vista_tentativa, tentativa, tentativa==valida}
                            {tentativa, valida}
                        else
                            if tentativa.copia == :undefined do
                                tentativa = %{num_vista: tentativa.num_vista + 1, primario: tentativa.primario, copia: nodo_emisor}
                                send {:cliente_gv, nodo_emisor}, {:vista_tentativa, tentativa, tentativa==valida}
                                {tentativa, valida}
                            else
                                send {:cliente_gv, nodo_emisor}, {:vista_tentativa, tentativa, tentativa==valida}
                                {tentativa, valida}
                            end
                        end
                        
                    {:obten_vista, pid} ->
                        send pid, {:vista_vista_v, valida, tentativa==valida}
                        {tentativa, valida}

                        ### VUESTRO CODIGO                
                        {tentativa, valida}
                    :procesa_situacion_servidores ->
                
                        ### VUESTRO CODIGO
                        {tentativa, valida}
        end

        bucle_recepcion(tentativa, valida)
    end
    
    # OTRAS FUNCIONES PRIVADAS VUESTRAS

end
