require 'formula'

# Documentation: https://github.com/mxcl/homebrew/wiki/Formula-Cookbook
# PLEASE REMOVE ALL GENERATED COMMENTS BEFORE SUBMITTING YOUR PULL REQUEST!

class Pljava < Formula
  homepage 'http://pgfoundry.org/projects/pljava'
  url 'http://pgfoundry.org/frs/download.php/3280/pljava-src-snapshot.20120525.0.tar.gz'
  version '1.4.3a'
  sha1 '9cd5939d7196535a522571cf745b3d04d362790d'

  def install
    ENV.j1  # don't parallelize
    
    cc = `xcode-select --print-path`.chomp+"/usr/bin/gcc"
    print "Started the make\n"
    system "make","-d","-j1","CC=#{cc}","PG_CONFIG=/usr/local/bin/pg_config"  # builds but doesn't install
    lib.install 'build/objs/pljava.so', 'build/pljava.jar'

    # this assumes that the default psql connection is a sysadmin
    puts (IO.popen("#{HOMEBREW_PREFIX}/bin/psql","r+") { |io| io.write(sqlinstall); io.close_write; io.read })
    # system "java -cp build/deploy.jar org.postgresql.pljava.deploy.Deployer -install -user #{pgusr} -password #{pgpwd}"
    # would be nice to edit  postgresql.conf to point to pljava.so and pljava.jar, but I don't know where it is
  end

  def test
    # This test will fail and we won't accept that! It's enough to just replace
    # "false" with the main program this formula installs, but it'd be nice if you
    # were more thorough. Run the test with `brew test pljava`.
    system "false"
  end

  def patches
      DATA
  end

  def caveats
    <<-EOS.undent
    Installation assumes that the default psql connection is a sysadmin.

    Append the following two lines to the end of postgresql.conf
    
    dynamic_library_path = '$libdir:#{HOMEBREW_PREFIX}/lib'
    pljava.classpath='#{HOMEBREW_PREFIX}/pljava.jar'

    then restart postgres (pg_ctl restart).

    EOS
  end

  def sqlinstall;<<-EOS
DO $$
BEGIN
  IF NOT EXISTS( SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'sqlj')
  THEN EXECUTE 'CREATE SCHEMA sqlj';
  END IF;
END
$$;

GRANT USAGE ON SCHEMA sqlj TO public;

CREATE or REPLACE FUNCTION sqlj.java_call_handler() RETURNS language_handler AS 'pljava' LANGUAGE C;
CREATE or REPLACE TRUSTED LANGUAGE java HANDLER sqlj.java_call_handler;
CREATE or REPLACE FUNCTION sqlj.javau_call_handler() RETURNS language_handler AS 'pljava' LANGUAGE C;
CREATE or REPLACE LANGUAGE javaU HANDLER sqlj.javau_call_handler;

CREATE TABLE IF NOT EXISTS sqlj.jar_repository(
	jarId		SERIAL PRIMARY KEY,
	jarName		VARCHAR(100) UNIQUE NOT NULL,
	jarOrigin   VARCHAR(500) NOT NULL,
	jarOwner	NAME NOT NULL,
	jarManifest	TEXT,
   deploymentDesc INT
);

GRANT SELECT ON sqlj.jar_repository TO public;

CREATE TABLE IF NOT EXISTS sqlj.jar_entry(
   entryId	SERIAL PRIMARY KEY,
   entryName	VARCHAR(200) NOT NULL,
   jarId	INT NOT NULL REFERENCES sqlj.jar_repository ON DELETE CASCADE,
   entryImage  	BYTEA NOT NULL,
   UNIQUE(jarId, entryName)
);

GRANT SELECT ON sqlj.jar_entry TO public;

ALTER TABLE sqlj.jar_repository ADD FOREIGN KEY (deploymentDesc) REFERENCES sqlj.jar_entry ON DELETE SET NULL;


CREATE TABLE IF NOT EXISTS sqlj.classpath_entry(
	schemaName	VARCHAR(30) NOT NULL,
	ordinal		INT2 NOT NULL,
	jarId		INT NOT NULL REFERENCES sqlj.jar_repository ON DELETE CASCADE,
	PRIMARY KEY(schemaName, ordinal)
);

GRANT SELECT ON sqlj.classpath_entry TO public;


CREATE TABLE IF NOT EXISTS sqlj.typemap_entry(
	mapId		SERIAL PRIMARY KEY,
	javaName	VARCHAR(200) NOT NULL,
	sqlName		NAME NOT NULL
);
GRANT SELECT ON sqlj.typemap_entry TO public;


CREATE OR REPLACE  FUNCTION sqlj.install_jar(VARCHAR, VARCHAR, BOOLEAN) RETURNS void
	AS 'org.postgresql.pljava.management.Commands.installJar'
	LANGUAGE java SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sqlj.replace_jar(VARCHAR, VARCHAR, BOOLEAN) RETURNS void
	AS 'org.postgresql.pljava.management.Commands.replaceJar'
	LANGUAGE java SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sqlj.remove_jar(VARCHAR, BOOLEAN) RETURNS void
	AS 'org.postgresql.pljava.management.Commands.removeJar'
	LANGUAGE java SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sqlj.install_jar(BYTEA, VARCHAR, BOOLEAN) RETURNS void
	AS 'org.postgresql.pljava.management.Commands.installJar'
	LANGUAGE java SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sqlj.replace_jar(BYTEA, VARCHAR, BOOLEAN) RETURNS void
	AS 'org.postgresql.pljava.management.Commands.replaceJar'
	LANGUAGE java SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sqlj.set_classpath(VARCHAR, VARCHAR) RETURNS void
	AS 'org.postgresql.pljava.management.Commands.setClassPath'
	LANGUAGE java SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sqlj.get_classpath(VARCHAR) RETURNS VARCHAR
	AS 'org.postgresql.pljava.management.Commands.getClassPath'
	LANGUAGE java STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sqlj.add_type_mapping(VARCHAR, VARCHAR) RETURNS void
	AS 'org.postgresql.pljava.management.Commands.addTypeMapping'
	LANGUAGE java SECURITY DEFINER;

CREATE OR REPLACE FUNCTION sqlj.drop_type_mapping(VARCHAR) RETURNS void
	AS 'org.postgresql.pljava.management.Commands.dropTypeMapping'
	LANGUAGE java SECURITY DEFINER;
EOS
  end


end
__END__
diff --git  a/src/java/Makefile.global b/src/java/Makefile.global
--- a/src/java/Makefile.global
+++ b/src/java/Makefile.global
@@ -19,7 +19,7 @@
   GCJ	 := gcj
   JAVAC := $(GCJ) -C
 else
-	JAVAC	:= javac -source 1.6 -target 1.6
+	JAVAC	:= /System/Library/Java/JavaVirtualMachines/1.6.0.jdk/Contents/Home/bin/javac -source 1.6 -target 1.6
 endif
 
 JARFILE	:= $(TARGETDIR)/$(NAME).jar
