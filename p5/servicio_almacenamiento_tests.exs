Code.require_file("#{__DIR__}/nodo_remoto.exs")
Code.require_file("#{__DIR__}/servidor_gv.exs")
Code.require_file("#{__DIR__}/cliente_gv.exs")
Code.require_file("#{__DIR__}/servidor_sa.exs")
Code.require_file("#{__DIR__}/cliente_sa.exs")

# Poner en marcha el servicio de tests unitarios con tiempo de vida limitada
# seed: 0 para que la ejecucion de tests no tenga orden aleatorio
# milisegundos
ExUnit.start(timeout: 20000, seed: 0, exclude: [:deshabilitado])

defmodule ServicioAlmacenamientoTest do
  use ExUnit.Case

  # @moduletag timeout 100  para timeouts de todos lo test de este modulo

  @maquinas ["127.0.0.1", "127.0.0.1", "127.0.0.1", "127.0.0.1"]
  # @maquinas ["155.210.154.192", "155.210.154.193", "155.210.154.194"]

  # @latidos_fallidos 4

  # @intervalo_latido 50

  # setup_all do

  # @tag :deshabilitado
  test "Test 1: solo_arranque y parada" do
    IO.puts("Test: Solo arranque y parada ...")

    # Poner en marcha nodos, clientes, servidores alm., en @maquinas
    mapNodos = startServidores(["ca1"], ["sa1"], @maquinas)

    Process.sleep(300)

    # Parar todos los nodos y epmds
    stopServidores(mapNodos, @maquinas)

    IO.puts(" ... Superado")
  end

  # @tag :deshabilitado
  test "Test 2: Algunas escrituras" do
    # :io.format "Pids de nodo MAESTRO ~p: principal = ~p~n", [node, self]

    # Process.flag(:trap_exit, true)

    # Para que funcione bien la función  ClienteGV.obten_vista
    Process.register(self(), :servidor_sa)

    # Arrancar nodos : 1 GV, 3 servidores y 1 cliente de almacenamiento
    mapa_nodos = startServidores(["ca1"], ["sa1", "sa2", "sa3"], @maquinas)

    # Espera configuracion y relacion entre nodos
    Process.sleep(200)

    IO.puts("Test: Comprobar escritura con primario, copia y espera ...")

    # Comprobar primeros nodos primario y copia
    {%{primario: p, copia: c}, _ok} = ClienteGV.obten_vista(mapa_nodos.gv)
    assert p == mapa_nodos.sa1
    assert c == mapa_nodos.sa2

    ClienteSA.escribe(mapa_nodos.ca1, "a", "aa")
    ClienteSA.escribe(mapa_nodos.ca1, "b", "bb")
    ClienteSA.escribe(mapa_nodos.ca1, "c", "cc")
    comprobar(mapa_nodos.ca1, "a", "aa")
    comprobar(mapa_nodos.ca1, "b", "bb")
    comprobar(mapa_nodos.ca1, "c", "cc")

    IO.puts(" ... Superado")

    IO.puts("Test: Comprobar escritura despues de fallo de nodo copia ...")

    # Provocar fallo de nodo copia y seguido realizar una escritura
    {%{copia: nodo_copia}, _} = ClienteGV.obten_vista(mapa_nodos.gv)
    # Provocar parada nodo copia
    NodoRemoto.stop(nodo_copia)

    # esperar a reconfiguracion de servidores
    Process.sleep(700)

    ClienteSA.escribe(mapa_nodos.ca1, "a", "aaa")
    comprobar(mapa_nodos.ca1, "a", "aaa")

    # Comprobar los nuevo nodos primario y copia
    {%{primario: p, copia: c}, _ok} = ClienteGV.obten_vista(mapa_nodos.gv)
    assert p == mapa_nodos.sa1
    assert c == mapa_nodos.sa3

    IO.puts(" ... Superado")

    # Parar todos los nodos y epmds
    stopServidores(mapa_nodos, @maquinas)
  end

  # @tag :deshabilitado
  test "Test 3 : Mismos valores concurrentes" do
    IO.puts("Test: Escrituras mismos valores clientes concurrentes ...")

    # Para que funcione bien la función  ClienteGV.obten_vista
    Process.register(self(), :servidor_sa)

    # Arrancar nodos : 1 GV, 3 servidores y 3 cliente de almacenamiento
    mapa_nodos =
      startServidores(
        ["ca1", "ca2", "ca3"],
        ["sa1", "sa2", "sa3"],
        @maquinas
      )

    # Espera configuracion y relacion entre nodos
    Process.sleep(200)

    # Comprobar primeros nodos primario y copia
    {%{primario: p, copia: c}, _ok} = ClienteGV.obten_vista(mapa_nodos.gv)
    assert p == mapa_nodos.sa1
    assert c == mapa_nodos.sa2

    # Escritura concurrente de mismas 2 claves, pero valores diferentes
    # Posteriormente comprobar que estan igual en primario y copia
    escritura_concurrente(mapa_nodos)

    Process.sleep(200)

    # Obtener valor de las clave "0" y "1" con el primer primario
    valor1primario = ClienteSA.lee(mapa_nodos.ca1, "0")
    valor2primario = ClienteSA.lee(mapa_nodos.ca3, "1")

    # Forzar parada de primario
    NodoRemoto.stop(ClienteGV.primario(mapa_nodos.gv))

    # Esperar detección fallo y reconfiguración copia a primario
    Process.sleep(700)

    # Obtener valor de clave "0" y "1" con segundo primario (copia anterior)
    valor1copia = ClienteSA.lee(mapa_nodos.ca3, "0")
    valor2copia = ClienteSA.lee(mapa_nodos.ca2, "1")

    IO.puts(
      "valor1primario = #{valor1primario}, valor1copia = #{valor1copia}" <>
        "valor2primario = #{valor2primario}, valor2copia = #{valor2copia}"
    )

    # Verificar valores obtenidos con primario y copia inicial
    assert valor1primario == valor1copia
    assert valor2primario == valor2copia

    # Parar todos los nodos y epmds
    stopServidores(mapa_nodos, @maquinas)

    IO.puts(" ... Superado")
  end

  # Test 4 : Escrituras concurrentes y comprobación de consistencia
  #         tras caída de primario y copia.
  #         Se puede gestionar con cuatro nodos o con el primario rearrancado.

  # @tag :deshabilitado
  test "Test 4 : escrituras concurrentes y comprobacion de consistencia" do
    IO.puts("Test: Escrituras concurrentes y comprobacion de consistencia")

    # Para que funcione bien la función  ClienteGV.obten_vista
    Process.register(self(), :servidor_sa)

    # Arrancar nodos : 1 GV, 4 servidores y 3 cliente de almacenamiento
    mapa_nodos =
      startServidores(
        ["ca1", "ca2", "ca3"],
        ["sa1", "sa2", "sa3", "sa4"],
        @maquinas
      )

    # Espera configuracion y relacion entre nodos
    Process.sleep(200)

    # Comprobar primeros nodos primario y copia
    {%{primario: p, copia: c}, _ok} = ClienteGV.obten_vista(mapa_nodos.gv)
    assert p == mapa_nodos.sa1
    assert c == mapa_nodos.sa2

    # Escritura concurrente de mismas 2 claves, pero valores diferentes
    # Posteriormente comprobar que estan igual en primario y copia
    escritura_concurrente2(mapa_nodos)

    Process.sleep(200)

    # Obtener valor de las clave "0" y "1" con el primer primario
    valor1primario = ClienteSA.lee(mapa_nodos.ca1, "0")
    valor2primario = ClienteSA.lee(mapa_nodos.ca2, "1")
    valor3primario = ClienteSA.lee(mapa_nodos.ca1, "2")
    valor4primario = ClienteSA.lee(mapa_nodos.ca2, "3")
    valor5primario = ClienteSA.lee(mapa_nodos.ca2, "4")

    # Forzar parada de primario
    NodoRemoto.stop(ClienteGV.primario(mapa_nodos.gv))

    # Esperar detección fallo y reconfiguración copia a primario
    Process.sleep(700)

    # Forzar parada del nuevo nodo primario (anterior copia)
    NodoRemoto.stop(ClienteGV.primario(mapa_nodos.gv))

    # Esperar detección fallo y reconfiguración copia a primario
    Process.sleep(700)

    # Obtener valor de clave "0" y "1" con segundo primario (espera anterior)
    valor1newPrimario = ClienteSA.lee(mapa_nodos.ca3, "0")
    valor2newPrimario = ClienteSA.lee(mapa_nodos.ca1, "1")
    valor3newPrimario = ClienteSA.lee(mapa_nodos.ca3, "2")
    valor4newPrimario = ClienteSA.lee(mapa_nodos.ca3, "3")
    valor5newPrimario = ClienteSA.lee(mapa_nodos.ca1, "4")

    # Verificar valores obtenidos con primario y nuevo primario
    assert valor1primario == valor1newPrimario
    assert valor2primario == valor2newPrimario
    assert valor3primario == valor3newPrimario
    assert valor4primario == valor4newPrimario
    assert valor5primario == valor5newPrimario

    # Parar todos los nodos y epmds
    stopServidores(mapa_nodos, @maquinas)

    IO.puts(" ... Superado")
  end

  # Test 5 : Petición de escritura inmediatamente después de la caída de nodo
  #         copia (con uno en espera que le reemplace).

  # @tag :deshabilitado
  test "Test 5 : escritura inmediatamente después de la caída del nodo copia" do
    IO.puts("Test: Escrituras después de la caída del nodo copia")

    # Para que funcione bien la función  ClienteGV.obten_vista
    Process.register(self(), :servidor_sa)

    # Arrancar nodos : 1 GV, 4 servidores y 3 cliente de almacenamiento
    mapa_nodos =
      startServidores(
        ["ca1", "ca2", "ca3"],
        ["sa1", "sa2", "sa3", "sa4"],
        @maquinas
      )

    # Espera configuracion y relacion entre nodos
    Process.sleep(200)

    # Comprobar primeros nodos primario y copia
    {%{primario: p, copia: c}, _ok} = ClienteGV.obten_vista(mapa_nodos.gv)
    assert p == mapa_nodos.sa1
    assert c == mapa_nodos.sa2

    # Forzar parada del nodo copia
    NodoRemoto.stop(c)

    ClienteSA.escribe(mapa_nodos.ca1, "a", "aa")
    valorPrimario = ClienteSA.lee(mapa_nodos.ca3, "a")

    # Se comprueba que el valor guardado es el primario
    assert "aa" == valorPrimario

    Process.sleep(700)

    # Para comprobar que el valor también se encuentra correctamente
    # cae el primario
    NodoRemoto.stop(p)

    Process.sleep(700)

    valorNewPrimario = ClienteSA.lee(mapa_nodos.ca3, "a")

    assert "aa" == valorNewPrimario

    # Parar todos los nodos y epmds
    stopServidores(mapa_nodos, @maquinas)

    IO.puts(" ... Superado")
  end

  # Test 6 : Petición de escritura duplicada por perdida de respuesta
  #         (modificación realizada en BD), con primario y copia.

  # @tag :deshabilitado
  test "Test 6 : Comprobación de escritura ducplicada" do
    IO.puts("Test: Comprobación de escritura duplicada")

    # Para que funcione bien la función  ClienteGV.obten_vista
    Process.register(self(), :servidor_sa)

    # Arrancar nodos : 1 GV, 4 servidores y 3 cliente de almacenamiento
    mapa_nodos =
      startServidores(
        ["ca1", "ca2", "ca3"],
        ["sa1", "sa2", "sa3", "sa4"],
        @maquinas
      )

    # Espera configuracion y relacion entre nodos
    Process.sleep(200)

    # Comprobar primeros nodos primario y copia
    {%{primario: p, copia: c}, _ok} = ClienteGV.obten_vista(mapa_nodos.gv)
    assert p == mapa_nodos.sa1
    assert c == mapa_nodos.sa2

    ClienteSA.escribe(mapa_nodos.ca1, "a", "aa")
    ClienteSA.escribe(mapa_nodos.ca1, "a", "aa")
    valorPrimario = ClienteSA.lee(mapa_nodos.ca3, "a")

    # Se comprueba que el valor guardado es el primario
    assert "aa" == valorPrimario

    # Parar todos los nodos y epmds
    stopServidores(mapa_nodos, @maquinas)

    IO.puts(" ... Superado")
  end

  # Test 7 : Comprobación de que un antiguo primario no debería servir
  #         operaciones de lectura.

  # @tag :deshabilitado
  test "Test 7 : Comprobación de que un antiguo primario no debería servir para lectura" do
    IO.puts(
      "Test: Comprobación de que un antiguo primario no debería servir para lectura"
    )

    # Para que funcione bien la función  ClienteGV.obten_vista
    Process.register(self(), :servidor_sa)

    # Arrancar nodos : 1 GV, 4 servidores y 3 cliente de almacenamiento
    mapa_nodos =
      startServidores(
        ["ca1", "ca2", "ca3"],
        ["sa1", "sa2", "sa3", "sa4"],
        @maquinas
      )

    # Espera configuracion y relacion entre nodos
    Process.sleep(200)

    # Comprobar primeros nodos primario y copia
    {%{primario: p, copia: c}, _ok} = ClienteGV.obten_vista(mapa_nodos.gv)
    assert p == mapa_nodos.sa1
    assert c == mapa_nodos.sa2

    ClienteSA.escribe(mapa_nodos.ca1, "a", "aa")
    valorPrimario = ClienteSA.lee(mapa_nodos.ca3, "a")

    # Se comprueba que el valor guardado es el primario
    assert "aa" == valorPrimario

    NodoRemoto.stop(p)

    Process.sleep(700)

    startServidoresSinGV([], ["sa1"], @maquinas, mapa_nodos.gv)

    Process.sleep(700)

    # Se hace una operación de lectura sobre el antiguo nodo primario
    valor = ClienteSA.lee_manual("a", p)

    assert valor == nil

    # Parar todos los nodos y epmds
    stopServidores(mapa_nodos, @maquinas)

    IO.puts(" ... Superado")
  end

  # Test 8 : Escrituras concurrentes de varios clientes sobre la misma clave,
  #         con comunicación con fallos (sobre todo pérdida de repuestas para
  #         comprobar gestión correcta de duplicados).

  # Test 9 : Comprobación de que un antiguo primario que se encuentra en otra
  #         partición de red no debería completar operaciones de lectura.

  # ------------------ FUNCIONES DE APOYO A TESTS ------------------------

  defp startServidores(clientes, serv_alm, maquinas) do
    tiempo_antes = :os.system_time(:milli_seconds)

    # Poner en marcha gestor de vistas y clientes almacenamiento
    sv = ServidorGV.startNodo("sv", "127.0.0.1")
    # Mapa con nodos cliente de almacenamiento
    clientesAlm =
      for c <- clientes, into: %{} do
        {String.to_atom(c), ClienteSA.startNodo(c, "127.0.0.1")}
      end

    ServidorGV.startService(sv)
    for {_, n} <- clientesAlm, do: ClienteSA.startService(n, sv)

    # Mapa con nodos servidores almacenamiento                 
    servAlm =
      for {s, m} <- Enum.zip(serv_alm, maquinas), into: %{} do
        {String.to_atom(s), ServidorSA.startNodo(s, m)}
      end

    # Poner en marcha servicios de cada nodo servidor de almacenamiento
    for {_, n} <- servAlm do
      ServidorSA.startService(n, sv)
      # Process.sleep(60)
    end

    # Tiempo de puesta en marcha de nodos
    t_total = :os.system_time(:milli_seconds) - tiempo_antes
    IO.puts("Tiempo puesta en marcha de nodos  : #{t_total}")

    %{gv: sv} |> Map.merge(clientesAlm) |> Map.merge(servAlm)
  end

  defp startServidoresSinGV(clientes, serv_alm, maquinas, sv) do
    tiempo_antes = :os.system_time(:milli_seconds)

    # Mapa con nodos cliente de almacenamiento
    clientesAlm =
      for c <- clientes, into: %{} do
        {String.to_atom(c), ClienteSA.startNodo(c, "127.0.0.1")}
      end

    for {_, n} <- clientesAlm, do: ClienteSA.startService(n, sv)

    # Mapa con nodos servidores almacenamiento                 
    servAlm =
      for {s, m} <- Enum.zip(serv_alm, maquinas), into: %{} do
        {String.to_atom(s), ServidorSA.startNodo(s, m)}
      end

    # Poner en marcha servicios de cada nodo servidor de almacenamiento
    for {_, n} <- servAlm do
      ServidorSA.startService(n, sv)
      # Process.sleep(60)
    end

    # Tiempo de puesta en marcha de nodos
    t_total = :os.system_time(:milli_seconds) - tiempo_antes
    IO.puts("Tiempo puesta en marcha de nodos  : #{t_total}")
  end

  defp stopServidores(nodos, maquinas) do
    IO.puts("Finalmente eliminamos nodos")

    # Primero el gestor de vistas para no tener errores por fallo de 
    # servidores de almacenamiento
    {%{gv: nodoGV}, restoNodos} = Map.split(nodos, [:gv])
    IO.inspect(nodoGV, label: "nodo GV :")
    NodoRemoto.stop(nodoGV)
    IO.puts("UNo")
    Enum.each(restoNodos, fn {_, nodo} -> NodoRemoto.stop(nodo) end)
    IO.puts("DOS")

    # Eliminar epmd en cada maquina con nodos Elixir                            
    Enum.each(maquinas, fn m -> NodoRemoto.killEpmd(m) end)
  end

  defp comprobar(nodo_cliente, clave, valor_a_comprobar) do
    valor_en_almacen = ClienteSA.lee(nodo_cliente, clave)

    assert valor_en_almacen == valor_a_comprobar
  end

  def siguiente_valor(previo, actual) do
    ServidorSA.hash(previo <> actual) |> Integer.to_string()
  end

  # Ejecutar durante un tiempo una escritura continuada de 3 clientes sobre
  # las mismas 2 claves pero con 3 valores diferentes de forma concurrente
  def escritura_concurrente(mapa_nodos) do
    aleat1 = :rand.uniform(1000)
    pid1 = spawn(__MODULE__, :bucle_infinito, [mapa_nodos.ca1, aleat1])
    aleat2 = :rand.uniform(1000)
    pid2 = spawn(__MODULE__, :bucle_infinito, [mapa_nodos.ca2, aleat2])
    aleat3 = :rand.uniform(1000)
    pid3 = spawn(__MODULE__, :bucle_infinito, [mapa_nodos.ca3, aleat3])

    Process.sleep(2000)

    Process.exit(pid1, :kill)
    Process.exit(pid2, :kill)
    Process.exit(pid3, :kill)
  end

  def bucle_infinito(nodo_cliente, aleat) do
    # solo claves "0" y "1"
    clave = Integer.to_string(rem(aleat, 2))
    valor = Integer.to_string(aleat)
    miliseg = :rand.uniform(200)

    Process.sleep(miliseg)

    # :io.format "Nodo ~p, escribe clave = ~p, valor = ~p, sleep = ~p~n",
    #            [Node.self(), clave, valor, miliseg]

    ClienteSA.escribe(nodo_cliente, clave, valor)

    bucle_infinito(nodo_cliente, aleat)
  end

  def escritura_concurrente2(mapa_nodos) do
    pid1 = spawn(__MODULE__, :bucle_infinito2, [mapa_nodos.ca1])
    pid2 = spawn(__MODULE__, :bucle_infinito2, [mapa_nodos.ca2])
    pid3 = spawn(__MODULE__, :bucle_infinito2, [mapa_nodos.ca3])

    Process.sleep(2000)

    Process.exit(pid1, :kill)
    Process.exit(pid2, :kill)
    Process.exit(pid3, :kill)
  end

  def bucle_infinito2(nodo_cliente) do
    # solo claves "0" y "4"
    clave = Integer.to_string(:rand.uniform(5) - 1)
    valor = Integer.to_string(:rand.uniform(1000))
    miliseg = :rand.uniform(200)

    Process.sleep(miliseg)

    # :io.format "Nodo ~p, escribe clave = ~p, valor = ~p, sleep = ~p~n",
    #            [Node.self(), clave, valor, miliseg]

    ClienteSA.escribe(nodo_cliente, clave, valor)

    bucle_infinito2(nodo_cliente)
  end
end
