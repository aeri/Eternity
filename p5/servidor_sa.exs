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
    String.to_charlist(string_concatenado) |> :erlang.phash2()
  end

  @doc """
      Poner en marcha el servidor para gestión de vistas
      Devolver atomo que referencia al nuevo nodo Elixir
  """
  @spec startNodo(String.t(), String.t()) :: node
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

  # ------------------- Funciones privadas -----------------------------

  def init_sa(nodo_servidor_gv) do
    Process.register(self(), :servidor_sa)
    # Process.register(self(), :cliente_gv)

    spawn(__MODULE__, :enviar_latido, [self()])

    {:vista_tentativa, vista, _} = ClienteGV.latido(nodo_servidor_gv, 0)
    # Poner estado inicial
    bucle_recepcion_principal(%{}, vista, nodo_servidor_gv)
  end

  # Cada 50ms se envía un mensaje que se recibe 
  # en el bucle_recepcion_principal para avisar de que
  # se debe enviar un latido al servidor GV
  def enviar_latido(pid) do
    send(pid, :enviar_latido)
    Process.sleep(@intervalo_latido)
    enviar_latido(pid)
  end

  defp bucle_recepcion_principal(bbdd, vista, nodo_servidor_gv) do
    {bbdd, vista, nodo_servidor_gv} =
      receive do
        # Solicitudes de lectura y escritura
        # de clientes del servicio alm.
        {op, param, pid_origen} ->
          if Node.self() == vista.primario do
            {bbdd} = realizar_operacion(op, bbdd, param, pid_origen, vista)
            {bbdd, vista, nodo_servidor_gv}
          else
            IO.puts("Soy un nodo copia")
            send(pid_origen, {:resultado, :no_soy_primario_valido})
            {bbdd, vista, nodo_servidor_gv}
          end

        # Recibe los datos de la base por parte del nodo primario 
        # siendo el nodo copia
        {database, primario_pid} ->
          IO.puts("Datos recibidos de la base en el nodo copia")
          send(primario_pid, {:check})
          {database, vista, nodo_servidor_gv}

        # Recibe un mensaje que le indica que debe enviar un latido
        # al servidor GV
        :enviar_latido ->
          {:vista_tentativa, newvista, _} =
            ClienteGV.latido(nodo_servidor_gv, vista.num_vista)

          if vista.num_vista != newvista.num_vista and
               newvista.copia != :undefined and
               newvista.primario == Node.self() do
            # Si cambia el número de vista, soy el primario y hay un nodo copia
            # se copia la base al nodo copia
            IO.puts("Copiando de primario a copia la base de datos")
            send({:servidor_sa, newvista.copia}, {bbdd, self()})
          end

          {bbdd, newvista, nodo_servidor_gv}
      end

    bucle_recepcion_principal(bbdd, vista, nodo_servidor_gv)
  end

  # Realiza la operación que solicita el cliente al nodo primario
  def realizar_operacion(op, bbdd, param, pid_origen, vista) do
    case op do
      # Operación de lectura
      :lee ->
        valor = bbdd[param]
        send(pid_origen, {:resultado, valor})
        {bbdd}

      # Operación de escritura
      :escribe_generico ->
        {clave, valor, _} = param

        if bbdd[clave] == valor do
          # La clave ya existía y tenía el valor
          # que el cliente solicita escribir
          # Por lo tanto no se escribe para evitar operaciones duplicadas
          IO.puts("Operación repetida: no se realiza la operacion")
          send(pid_origen, {:resultado, valor})
          {bbdd}
        else
          newbbdd = Map.put(bbdd, clave, valor)
          IO.puts("Datos escritos en el primario")
          # Se copian los cambios al nodo copia
          send({:servidor_sa, vista.copia}, {newbbdd, self()})

          receive do
            {:check} ->
              send(pid_origen, {:resultado, valor})
              {newbbdd}
          after
            @intervalo_latido ->
              {bbdd}
          end
        end
    end
  end
end
