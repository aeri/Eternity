Code.require_file("#{__DIR__}/cliente_gv.exs")

defmodule ServidorSA do
    
    # estado del servidor            
    # defstruct   ???????????????????????


    @intervalo_latido 50


    @doc """
        Obtener el hash de un string Elixir
            - Necesario pasar, previamente,  a formato string Erlang
         - Devuelve entero
    """
    def hash(string_concatenado) do
        String.to_charlist(string_concatenado) |> :erlang.phash2
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
    @spec startService(node, node) :: pid
    def startService(nodoSA, nodo_servidor_gv) do
        NodoRemoto.esperaNodoOperativo(nodoSA, __MODULE__)
        
        # Poner en marcha el código del gestor de vistas
        Node.spawn(nodoSA, __MODULE__, :init_sa, [nodo_servidor_gv])
   end

    #------------------- Funciones privadas -----------------------------

    def init_sa(nodo_servidor_gv) do
        Process.register(self(), :servidor_sa)
        # Process.register(self(), :cliente_gv)
 
    	spawn(__MODULE__, :enviar_latido, [self()])

	{:vista_tentativa, vista, _} = ClienteGV.latido(nodo_servidor_gv, 0)
         # Poner estado inicial
        bucle_recepcion_principal(%{}, vista, nodo_servidor_gv) 
    end

    def enviar_latido(pid) do
	send(pid, :enviar_latido)
	Process.sleep(@intervalo_latido)
	enviar_latido(pid)
    end

    defp bucle_recepcion_principal(bbdd, vista, nodo_servidor_gv) do
         {bbdd, vista, nodo_servidor_gv} = receive do

                    # Solicitudes de lectura y escritura
                    # de clientes del servicio alm.
                {op, param, nodo_origen} ->
			if Node.self() == vista.primario do
				case op do
					:lee ->
						valor = bbdd[param]
                    				send {:cliente_sa, nodo_origen}, {:resultado, valor}
						{bbdd, vista, nodo_servidor_gv}
					:escribe_generico ->
						{clave, valor, _} = param
						newbbdd = Map.put(bbdd, clave, valor)
						IO.puts "Datos escritos en el primario"
						IO.inspect newbbdd
						# Se copian los cambios al nodo copia
						send {:servidor_sa, vista.copia}, {newbbdd, self()}
						receive do
							{:check} ->
								send {:cliente_sa, nodo_origen}, {:resultado, valor}
								{newbbdd, vista, nodo_servidor_gv}
						after @intervalo_latido ->
							{bbdd, vista, nodo_servidor_gv}
						end
				end
			else
				IO.puts "Soy un nodo copia"
                    		send nodo_origen, {:resultado, :no_soy_primario_valido}
				{bbdd, vista, nodo_servidor_gv}
			end

		{database, primario_pid} ->
			IO.puts "Datos recibidos de la base"
			IO.inspect database
			send primario_pid, {:check}
			{database, vista, nodo_servidor_gv} 

		:enviar_latido ->
			{:vista_tentativa, newvista, _} = ClienteGV.latido(nodo_servidor_gv, vista.num_vista)
			if vista.num_vista != newvista.num_vista and newvista.primario != :undefined and newvista.copia != :undefined and newvista.primario == Node.self() do
				IO.puts "Copiando de primario a copia la base de datos"
				IO.puts newvista.copia
				send {:servidor_sa, newvista.copia}, {bbdd, self()}
			end
			{bbdd, newvista, nodo_servidor_gv}
               	end
        bucle_recepcion_principal(bbdd, vista, nodo_servidor_gv)
    end
end
