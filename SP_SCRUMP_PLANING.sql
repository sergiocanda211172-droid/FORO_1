--Procedimientos_Almacenados
--sergio antonio canda poveda 211172
--Henry Yosec Benavides Amador 
 


USE [DB_SCRUM_PLANNING]
GO

CREATE OR ALTER PROC [SQM_CATALOGS].[USP_Status]
(
    @i_statusId INT = NULL,
    @i_statusName VARCHAR(80) = NULL,
    @i_statusCreationDate DATETIME = NULL,
    @i_statusCreatorId INT = NULL,
    @i_statusModificationDate DATETIME = NULL,
    @i_statusModificatorId INT = NULL,
    @i_statusEnable BIT = NULL,
    @i_PageNumber INT = NULL,
    @i_RowsPerPage INT = NULL,
    @w_Accion CHAR(1),
    @o_Numero INT = NULL OUT,
    @o_MensajeTecnico VARCHAR(500) = NULL OUT,
    @o_MensajeUsuario VARCHAR(500) = NULL OUT
)
AS
BEGIN
    DECLARE @w_totalRows INT;

    IF @i_statusCreationDate IS NULL
        SET @i_statusCreationDate = GETDATE();

    IF @i_statusModificationDate IS NULL
        SET @i_statusModificationDate = GETDATE();


    -- 1. ACCIÓN: INSERTAR (I)

    IF @w_Accion = 'I'
    BEGIN
        -- Validaciones de negocio
        IF ISNULL(@i_statusName, '') = ''
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL NOMBRE DEL ESTADO ES OBLIGATORIO';
        END
        ELSE IF ISNULL(@i_statusCreatorId, 0) = 0
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL ID DEL CREADOR ES OBLIGATORIO';
        END
        ELSE IF EXISTS (SELECT 1 FROM [SQM_CATALOGS].[TBL_Status] (NOLOCK) WHERE statusName = @i_statusName)
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL NOMBRE DEL ESTADO YA EXISTE';
        END
        ELSE
        BEGIN
            BEGIN TRANSACTION TRX_INS_STATUS;
            BEGIN TRY
                INSERT INTO [SQM_CATALOGS].[TBL_Status]
                (
                    statusName,
                    statusCreationDate,
                    statusCreatorId,
                    statusModificationDate,
                    statusModificatorId,
                    statusEnable
                )
                VALUES
                (
                    @i_statusName,
                    @i_statusCreationDate,
                    @i_statusCreatorId,
                    @i_statusModificationDate,
                    @i_statusModificatorId,
                    1
                );

                COMMIT TRANSACTION TRX_INS_STATUS;

                SET @o_Numero = 201;
                SET @o_MensajeUsuario = 'ESTADO REGISTRADO CORRECTAMENTE';
            END TRY
            BEGIN CATCH
                ROLLBACK TRANSACTION TRX_INS_STATUS;
                SET @o_Numero = 500;
                SET @o_MensajeUsuario = 'ERROR AL REGISTRAR EL ESTADO';
                SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL REGISTRAR ESTADO', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
            END CATCH
        END
    END


    -- 2. ACCIÓN: ACTUALIZAR (U)

    ELSE IF @w_Accion = 'U'
    BEGIN
        IF ISNULL(@i_statusId, 0) = 0
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL ID DEL ESTADO ES OBLIGATORIO';
        END
        ELSE IF ISNULL(@i_statusModificatorId, 0) = 0
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL ID DEL MODIFICADOR ES OBLIGATORIO';
        END
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_CATALOGS].[TBL_Status] (NOLOCK) WHERE statusId = @i_statusId)
        BEGIN
            SET @o_Numero = 404;
            SET @o_MensajeUsuario = 'EL ESTADO NO EXISTE';
        END
        ELSE IF @i_statusName IS NOT NULL AND EXISTS (SELECT 1 FROM [SQM_CATALOGS].[TBL_Status] (NOLOCK) WHERE statusName = @i_statusName AND statusId <> @i_statusId)
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL NOMBRE DEL ESTADO YA EXISTE EN OTRO REGISTRO';
        END
        ELSE
        BEGIN
            BEGIN TRANSACTION TRX_UPD_STATUS;
            BEGIN TRY
                UPDATE [SQM_CATALOGS].[TBL_Status]
                SET statusName = COALESCE(@i_statusName, statusName),
                    statusModificationDate = @i_statusModificationDate,
                    statusModificatorId = @i_statusModificatorId,
                    statusEnable = COALESCE(@i_statusEnable, statusEnable)
                WHERE statusId = @i_statusId;

                COMMIT TRANSACTION TRX_UPD_STATUS;

                SET @o_Numero = 200;
                SET @o_MensajeUsuario = 'ESTADO ACTUALIZADO CORRECTAMENTE';
            END TRY
            BEGIN CATCH
                ROLLBACK TRANSACTION TRX_UPD_STATUS;
                SET @o_Numero = 500;
                SET @o_MensajeUsuario = 'ERROR AL ACTUALIZAR EL ESTADO';
                SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL ACTUALIZAR ESTADO', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
            END CATCH
        END
    END

   
    -- 3. ACCIÓN: LISTAR CON PAGINACIÓN (S)
   
    ELSE IF @w_Accion = 'S'
    BEGIN
        BEGIN TRY
            -- Valores por defecto si no se ingresan páginas
            SET @i_PageNumber = ISNULL(@i_PageNumber, 1);
            SET @i_RowsPerPage = ISNULL(@i_RowsPerPage, 10);

            SELECT 
                statusId,
                statusName,
                statusCreationDate,
                statusCreatorId,
                statusModificationDate,
                statusModificatorId,
                statusEnable
            FROM [SQM_CATALOGS].[TBL_Status] (NOLOCK)
            ORDER BY statusId
            OFFSET (@i_PageNumber - 1) * @i_RowsPerPage ROWS
            FETCH NEXT @i_RowsPerPage ROWS ONLY;

            SET @w_totalRows = @@ROWCOUNT;

            IF (@w_totalRows > 0)
            BEGIN
                SET @o_Numero = 200;
                SET @o_MensajeUsuario = 'ESTADOS LISTADOS CORRECTAMENTE';
            END
            ELSE
            BEGIN
                SET @o_Numero = 204;
                SET @o_MensajeUsuario = 'NO HAY MÁS REGISTROS PARA LISTAR';
            END
        END TRY
        BEGIN CATCH
            SET @o_Numero = 500;
            SET @o_MensajeUsuario = 'ERROR AL LISTAR LOS ESTADOS';
            SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL LISTAR ESTADOS', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
        END CATCH
    END


    -- ACCIÓN INVALIDA

    ELSE
    BEGIN
        SET @o_Numero = 405;
        SET @o_MensajeUsuario = 'MÉTODO NO HABILITADO';
        SET @o_MensajeTecnico = 'EL PROCEDIMIENTO ALMACENADO NO TIENE HABILITADA ESA OPCIÓN';
    END
END;
GO



CREATE OR ALTER PROC [SQM_SECURITY].[USP_Roles]
(
    @i_rolId INT = NULL,
    @i_rolName VARCHAR(80) = NULL,
    @i_rolCreationDate DATETIME = NULL,
    @i_rolCreatorId INT = NULL,
    @i_rolModificationDate DATETIME = NULL,
    @i_rolModificatorId INT = NULL,
    @i_rolEnable BIT = NULL,
    @i_PageNumber INT = NULL,
    @i_RowsPerPage INT = NULL,
    @w_Accion CHAR(1),
    @o_Numero INT = NULL OUT,
    @o_MensajeTecnico VARCHAR(500) = NULL OUT,
    @o_MensajeUsuario VARCHAR(500) = NULL OUT
)
AS
BEGIN
    DECLARE @w_totalRows INT;

    IF @i_rolCreationDate IS NULL
        SET @i_rolCreationDate = GETDATE();

    IF @i_rolModificationDate IS NULL
        SET @i_rolModificationDate = GETDATE();

    -- 1. ACCIÓN: INSERTAR (I)

    IF @w_Accion = 'I'
    BEGIN
        IF ISNULL(@i_rolName, '') = ''
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL NOMBRE DEL ROL ES OBLIGATORIO';
        END
        ELSE IF ISNULL(@i_rolCreatorId, 0) = 0
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL ID DEL CREADOR ES OBLIGATORIO';
        END
        ELSE IF EXISTS (SELECT 1 FROM [SQM_SECURITY].[TBL_Roles] (NOLOCK) WHERE rolName = @i_rolName)
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL NOMBRE DEL ROL YA EXISTE';
        END
        ELSE
        BEGIN
            BEGIN TRANSACTION TRX_INS_ROL;
            BEGIN TRY
                INSERT INTO [SQM_SECURITY].[TBL_Roles]
                (
                    rolName,
                    rolCreationDate,
                    rolCreatorId,
                    rolModificationDate,
                    rolModificatorId,
                    rolEnable
                )
                VALUES
                (
                    @i_rolName,
                    @i_rolCreationDate,
                    @i_rolCreatorId,
                    @i_rolModificationDate,
                    @i_rolModificatorId,
                    1
                );

                COMMIT TRANSACTION TRX_INS_ROL;

                SET @o_Numero = 201;
                SET @o_MensajeUsuario = 'ROL REGISTRADO CORRECTAMENTE';
            END TRY
            BEGIN CATCH
                ROLLBACK TRANSACTION TRX_INS_ROL;
                SET @o_Numero = 500;
                SET @o_MensajeUsuario = 'ERROR AL REGISTRAR EL ROL';
                SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL REGISTRAR ROL', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
            END CATCH
        END
    END


    -- 2. ACCIÓN: ACTUALIZAR (U)

    ELSE IF @w_Accion = 'U'
    BEGIN
        IF ISNULL(@i_rolId, 0) = 0
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL ID DEL ROL ES OBLIGATORIO';
        END
        ELSE IF ISNULL(@i_rolModificatorId, 0) = 0
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL ID DEL MODIFICADOR ES OBLIGATORIO';
        END
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_SECURITY].[TBL_Roles] (NOLOCK) WHERE rolId = @i_rolId)
        BEGIN
            SET @o_Numero = 404;
            SET @o_MensajeUsuario = 'EL ROL NO EXISTE';
        END
        ELSE IF @i_rolName IS NOT NULL AND EXISTS (SELECT 1 FROM [SQM_SECURITY].[TBL_Roles] (NOLOCK) WHERE rolName = @i_rolName AND rolId <> @i_rolId)
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL NOMBRE DEL ROL YA EXISTE EN OTRO REGISTRO';
        END
        ELSE
        BEGIN
            BEGIN TRANSACTION TRX_UPD_ROL;
            BEGIN TRY
                UPDATE [SQM_SECURITY].[TBL_Roles]
                SET rolName = COALESCE(@i_rolName, rolName),
                    rolModificationDate = @i_rolModificationDate,
                    rolModificatorId = @i_rolModificatorId,
                    rolEnable = COALESCE(@i_rolEnable, rolEnable)
                WHERE rolId = @i_rolId;

                COMMIT TRANSACTION TRX_UPD_ROL;

                SET @o_Numero = 200;
                SET @o_MensajeUsuario = 'ROL ACTUALIZADO CORRECTAMENTE';
            END TRY
            BEGIN CATCH
                ROLLBACK TRANSACTION TRX_UPD_ROL;
                SET @o_Numero = 500;
                SET @o_MensajeUsuario = 'ERROR AL ACTUALIZAR EL ROL';
                SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL ACTUALIZAR ROL', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
            END CATCH
        END
    END

    -- 3. ACCIÓN: LISTAR CON PAGINACIÓN (S)

    ELSE IF @w_Accion = 'S'
    BEGIN
        BEGIN TRY
            SET @i_PageNumber = ISNULL(@i_PageNumber, 1);
            SET @i_RowsPerPage = ISNULL(@i_RowsPerPage, 10);

            SELECT 
                rolId,
                rolName,
                rolCreationDate,
                rolCreatorId,
                rolModificationDate,
                rolModificatorId,
                rolEnable
            FROM [SQM_SECURITY].[TBL_Roles] (NOLOCK)
            ORDER BY rolId
            OFFSET (@i_PageNumber - 1) * @i_RowsPerPage ROWS
            FETCH NEXT @i_RowsPerPage ROWS ONLY;

            SET @w_totalRows = @@ROWCOUNT;

            IF (@w_totalRows > 0)
            BEGIN
                SET @o_Numero = 200;
                SET @o_MensajeUsuario = 'ROLES LISTADOS CORRECTAMENTE';
            END
            ELSE
            BEGIN
                SET @o_Numero = 204;
                SET @o_MensajeUsuario = 'NO HAY MÁS REGISTROS PARA LISTAR';
            END
        END TRY
        BEGIN CATCH
            SET @o_Numero = 500;
            SET @o_MensajeUsuario = 'ERROR AL LISTAR LOS ROLES';
            SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL LISTAR ROLES', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
        END CATCH
    END


    -- ACCIÓN INVALIDA

    ELSE
    BEGIN
        SET @o_Numero = 405;
        SET @o_MensajeUsuario = 'MÉTODO NO HABILITADO';
        SET @o_MensajeTecnico = 'EL PROCEDIMIENTO ALMACENADO NO TIENE HABILITADA ESA OPCIÓN';
    END
END;
GO


CREATE OR ALTER PROC [SQM_SECURITY].[USP_Users]
(
    @i_userId INT = NULL,
    @i_userFullName VARCHAR(80) = NULL,
    @i_userName VARCHAR(80) = NULL,
    @i_userEmail VARCHAR(80) = NULL,
    @i_userPassword VARCHAR(256) = NULL,
    @i_userRolId INT = NULL,
    @i_userCreationDate DATETIME = NULL,
    @i_userCreatorId INT = NULL,
    @i_userModificationDate DATETIME = NULL,
    @i_userModificatorId INT = NULL,
    @i_userEnable BIT = NULL,
    @i_PageNumber INT = NULL,
    @i_RowsPerPage INT = NULL,
    @w_Accion CHAR(1),
    @o_Numero INT = NULL OUT,
    @o_MensajeTecnico VARCHAR(500) = NULL OUT,
    @o_MensajeUsuario VARCHAR(500) = NULL OUT
)
AS
BEGIN

    DECLARE @w_userPasswordEncrypted VARBINARY(256), @w_totalRows INT;

    IF @i_userCreationDate IS NULL
        SET @i_userCreationDate = GETDATE();

    IF @i_userModificationDate IS NULL
        SET @i_userModificationDate = GETDATE();

    -- INSERTAR USER --
    IF @w_Accion = 'I'
    BEGIN
        IF ISNULL(@i_userFullName,'') = ''
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL NOMBRE COMPLETO ES OBLIGATORIO';
        END;

        ELSE IF ISNULL(@i_userName,'') = ''
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL NOMBRE DE USUARIO ES OBLIGATORIO';
        END;

        ELSE IF ISNULL(@i_userEmail,'') = ''
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL CORREO ELECTRONICO ES OBLIGATORIO';
        END;

        ELSE IF ISNULL(@i_userPassword,'') = ''
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'LA CONTRASEÑA ES OBLIGATORIA';
        END;

        ELSE IF EXISTS (SELECT 1 FROM [SQM_SECURITY].[TBL_Users] (NOLOCK) WHERE userName = @i_userName)
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL NOMBRE DE USUARIO YA EXISTE';
        END;

        ELSE IF EXISTS (SELECT 1 FROM [SQM_SECURITY].[TBL_Users] (NOLOCK) WHERE userEmail = @i_userEmail)
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL CORREO YA EXISTE';
        END;

        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_CATALOGS].[TBL_Roles] (NOLOCK) WHERE rolId = @i_userRolId AND rolEnable = 1)
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL ROL NO EXISTE';
        END;
        
        ELSE
        BEGIN
            BEGIN TRANSACTION TRX_INS_USER;

            BEGIN TRY

                OPEN SYMMETRIC KEY KEY_HASH
                DECRYPTION BY CERTIFICATE CERT_SCRUMPLANNING;

                SET @w_userPasswordEncrypted = [SQM_SECURITY].[Fn_EncryptByKey](@i_userPassword);

                CLOSE SYMMETRIC KEY KEY_HASH;

                INSERT INTO [SQM_SECURITY].[TBL_Users](userFullName,userName,userEmail,userPassword,userRolId,userCreationDate,userCreatorId,userEnable)
                VALUES(@i_userFullName,@i_userName,@i_userEmail,@w_userPasswordEncrypted,@i_userRolId,@i_userCreationDate,@i_userCreatorId,1);

                COMMIT TRANSACTION TRX_INS_USER;

                SET @o_Numero = 201;
                SET @o_MensajeUsuario = 'USUARIO REGISTRADO CORRECTAMENTE';

            END TRY

            BEGIN CATCH

                ROLLBACK TRANSACTION TRX_INS_USER;

                SET @o_Numero = 500;
                SET @o_MensajeUsuario = 'ERROR AL REGISTRAR USUARIO';
                SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL REGISTRAR USUARIO', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());

            END CATCH
        END
    END

    -- UPDATE USER --
    ELSE IF @w_Accion = 'U'
    BEGIN

        IF ISNULL(@i_userId,0) = 0
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL ID DEL USUARIO ES OBLIGATORIO';
        END;

        IF ISNULL(@i_userModificatorId,0) = 0
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL ID DEL MODIFICADOR ES OBLIGATORIO';
        END;

        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_SECURITY].[TBL_Users] (NOLOCK) WHERE userId = @i_userId)
        BEGIN
            SET @o_Numero = 404;
            SET @o_MensajeUsuario = 'EL USUARIO NO EXISTE';
        END;

        ELSE IF @i_userName IS NOT NULL AND
            EXISTS (SELECT 1 FROM [SQM_SECURITY].[TBL_Users] (NOLOCK) WHERE userName = @i_userName
        AND userId <> @i_userId)
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL NOMBRE DE USUARIO YA EXISTE';
        END;

        ELSE IF @i_userEmail IS NOT NULL AND
            EXISTS (SELECT 1 FROM [SQM_SECURITY].[TBL_Users] (NOLOCK) WHERE userEmail = @i_userEmail
        AND userId <> @i_userId)
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL CORREO YA EXISTE';
        END;

        ELSE IF @i_userRolId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [SQM_CATALOGS].[TBL_Roles] (NOLOCK) 
		WHERE rolId = @i_userRolId AND rolEnable = 1)
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL ROL NO EXISTE';
        END;
        
        ELSE
        BEGIN
            BEGIN TRANSACTION TRX_UPD_USER;

            BEGIN TRY

                IF @i_userPassword IS NOT NULL
                BEGIN
                    OPEN SYMMETRIC KEY KEY_HASH
                    DECRYPTION BY CERTIFICATE CERT_SCRUMPLANNING;
                        SET @w_userPasswordEncrypted = [SQM_SECURITY].Fn_EncryptByKey(@i_userPassword);
                    CLOSE SYMMETRIC KEY KEY_HASH;
                END

                UPDATE [SQM_SECURITY].[TBL_Users]
                SET userFullName = COALESCE(@i_userFullName,userFullName),
                    userName = COALESCE(@i_userName,userName),
                    userEmail = COALESCE(@i_userEmail,userEmail),
                    userPassword = COALESCE(@w_userPasswordEncrypted,userPassword),
                    userRolId = COALESCE(@i_userRolId,userRolId),
                    userModificationDate = @i_userModificationDate,
                    userModificatorId = @i_userModificatorId,
                    userEnable = COALESCE(@i_userEnable,userEnable)
                WHERE userId = @i_userId;

                COMMIT TRANSACTION TRX_UPD_USER;

                SET @o_Numero = 200;
                SET @o_MensajeUsuario = 'USUARIO ACTUALIZADO CORRECTAMENTE';

            END TRY

            BEGIN CATCH
                ROLLBACK TRANSACTION TRX_UPD_USER;

                SET @o_Numero = 500;
                SET @o_MensajeUsuario = 'ERROR AL ACTUALIZAR USUARIO'
                SET @o_MensajeTecnico =  CONCAT_WS(' - ', 'ERROR AL ACTUALIZAR USUARIO', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());

            END CATCH
        END
    END

-- SELECT USER --
    ELSE IF @w_Accion = 'S'
    BEGIN

        BEGIN TRY

            SELECT 
                userId, 
                userFullName,
                userName,
                userEmail,
                userRolId,
                userCreationDate,
                userCreatorId,
                userModificationDate,
                userModificatorId,
                userEnable
            FROM [SQM_SECURITY].[TBL_Users] (NOLOCK)
            ORDER BY userId
            OFFSET (@i_PageNumber - 1) * @i_RowsPerPage ROWS
            FETCH NEXT @i_RowsPerPage ROWS ONLY;

            SET @w_totalRows = @@ROWCOUNT

            IF (@w_totalRows > 0)
            BEGIN
                SET @o_Numero = 200;
                SET @o_MensajeUsuario = 'USUARIOS LISTADOS CORRECTAMENTE';
            END
            ELSE
            BEGIN
                SET @o_Numero = 204;
                SET @o_MensajeUsuario = 'NO HAY MAS REGISTROS PARA LISTAR';
            END
        END TRY

        BEGIN CATCH

            SET @o_Numero = 500;
            SET @o_MensajeUsuario = 'ERROR AL LISTAR LOS USUARIOS';
            SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL LISTAR USUARIOS', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());

        END CATCH

    END

 -- ACCION INVALIDA --
    ELSE
    BEGIN

        SET @o_Numero = 405;
        SET @o_MensajeUsuario = 'METODO NO HABILITADO';
        SET @o_MensajeTecnico = 'EL PROCEDIMIENTO ALMACENADO NO TIENE HABILITADA ESA OPCION';

    END

END;
GO


CREATE OR ALTER PROC [SQM_CATALOGS].[USP_BusinessValues]
(
    @i_businessValueId INT = NULL,
    @i_businessValueName VARCHAR(80) = NULL,
    @i_businessValueCreationDate DATETIME = NULL,
    @i_businessValueCreatorId INT = NULL,
    @i_businessValueModificationDate DATETIME = NULL,
    @i_businessValueModificatorId INT = NULL,
    @i_businessValueEnable BIT = NULL,
    @i_PageNumber INT = NULL,
    @i_RowsPerPage INT = NULL,
    @w_Accion CHAR(1),
    @o_Numero INT = NULL OUT,
    @o_MensajeTecnico VARCHAR(500) = NULL OUT,
    @o_MensajeUsuario VARCHAR(500) = NULL OUT
)
AS
BEGIN
    DECLARE @w_totalRows INT;

    IF @i_businessValueCreationDate IS NULL
        SET @i_businessValueCreationDate = GETDATE();
    IF @i_businessValueModificationDate IS NULL
        SET @i_businessValueModificationDate = GETDATE();

    -- 1. INSERTAR (I)
    IF @w_Accion = 'I'
    BEGIN
        IF ISNULL(@i_businessValueName, '') = ''
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL NOMBRE DEL VALOR DE NEGOCIO ES OBLIGATORIO';
        END
        ELSE IF ISNULL(@i_businessValueCreatorId, 0) = 0
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL ID DEL CREADOR ES OBLIGATORIO';
        END
        ELSE IF EXISTS (SELECT 1 FROM [SQM_CATALOGS].[TBL_BusinessValues] (NOLOCK) WHERE businessValueName = @i_businessValueName)
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL NOMBRE DEL VALOR DE NEGOCIO YA EXISTE';
        END
        ELSE
        BEGIN
            BEGIN TRANSACTION TRX_INS_BV;
            BEGIN TRY
                INSERT INTO [SQM_CATALOGS].[TBL_BusinessValues]
                (businessValueName, businessValueCreationDate, businessValueCreatorId, businessValueModificationDate, businessValueModificatorId, businessValueEnable)
                VALUES
                (@i_businessValueName, @i_businessValueCreationDate, @i_businessValueCreatorId, @i_businessValueModificationDate, @i_businessValueModificatorId, 1);

                COMMIT TRANSACTION TRX_INS_BV;
                SET @o_Numero = 201;
                SET @o_MensajeUsuario = 'VALOR DE NEGOCIO REGISTRADO CORRECTAMENTE';
            END TRY
            BEGIN CATCH
                ROLLBACK TRANSACTION TRX_INS_BV;
                SET @o_Numero = 500;
                SET @o_MensajeUsuario = 'ERROR AL REGISTRAR VALOR DE NEGOCIO';
                SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL REGISTRAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
            END CATCH
        END
    END

    -- 2. ACTUALIZAR (U)
    ELSE IF @w_Accion = 'U'
    BEGIN
        IF ISNULL(@i_businessValueId, 0) = 0
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL ID DEL VALOR DE NEGOCIO ES OBLIGATORIO';
        END
        ELSE IF ISNULL(@i_businessValueModificatorId, 0) = 0
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL ID DEL MODIFICADOR ES OBLIGATORIO';
        END
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_CATALOGS].[TBL_BusinessValues] (NOLOCK) WHERE businessValueId = @i_businessValueId)
        BEGIN
            SET @o_Numero = 404;
            SET @o_MensajeUsuario = 'EL VALOR DE NEGOCIO NO EXISTE';
        END
        ELSE IF @i_businessValueName IS NOT NULL AND EXISTS (SELECT 1 FROM [SQM_CATALOGS].[TBL_BusinessValues] (NOLOCK) WHERE businessValueName = @i_businessValueName AND businessValueId <> @i_businessValueId)
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL NOMBRE YA EXISTE EN OTRO REGISTRO';
        END
        ELSE
        BEGIN
            BEGIN TRANSACTION TRX_UPD_BV;
            BEGIN TRY
                UPDATE [SQM_CATALOGS].[TBL_BusinessValues]
                SET businessValueName = COALESCE(@i_businessValueName, businessValueName),
                    businessValueModificationDate = @i_businessValueModificationDate,
                    businessValueModificatorId = @i_businessValueModificatorId,
                    businessValueEnable = COALESCE(@i_businessValueEnable, businessValueEnable)
                WHERE businessValueId = @i_businessValueId;

                COMMIT TRANSACTION TRX_UPD_BV;
                SET @o_Numero = 200;
                SET @o_MensajeUsuario = 'VALOR DE NEGOCIO ACTUALIZADO CORRECTAMENTE';
            END TRY
            BEGIN CATCH
                ROLLBACK TRANSACTION TRX_UPD_BV;
                SET @o_Numero = 500;
                SET @o_MensajeUsuario = 'ERROR AL ACTUALIZAR VALOR DE NEGOCIO';
                SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL ACTUALIZAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
            END CATCH
        END
    END

    -- 3. LISTAR (S)
    ELSE IF @w_Accion = 'S'
    BEGIN
        BEGIN TRY
            SET @i_PageNumber = ISNULL(@i_PageNumber, 1);
            SET @i_RowsPerPage = ISNULL(@i_RowsPerPage, 10);

            SELECT businessValueId, businessValueName, businessValueCreationDate, businessValueCreatorId, businessValueModificationDate, businessValueModificatorId, businessValueEnable
            FROM [SQM_CATALOGS].[TBL_BusinessValues] (NOLOCK)
            ORDER BY businessValueId
            OFFSET (@i_PageNumber - 1) * @i_RowsPerPage ROWS
            FETCH NEXT @i_RowsPerPage ROWS ONLY;

            SET @w_totalRows = @@ROWCOUNT;
            IF (@w_totalRows > 0)
            BEGIN
                SET @o_Numero = 200;
                SET @o_MensajeUsuario = 'VALORES DE NEGOCIO LISTADOS CORRECTAMENTE';
            END
            ELSE
            BEGIN
                SET @o_Numero = 204;
                SET @o_MensajeUsuario = 'NO HAY MÁS REGISTROS PARA LISTAR';
            END
        END TRY
        BEGIN CATCH
            SET @o_Numero = 500;
            SET @o_MensajeUsuario = 'ERROR AL LISTAR VALORES DE NEGOCIO';
            SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL LISTAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
        END CATCH
    END
    ELSE
    BEGIN
        SET @o_Numero = 405;
        SET @o_MensajeUsuario = 'MÉTODO NO HABILITADO';
    END
END;
GO


CREATE OR ALTER PROC [SQM_GENERAL].[USP_Initiatives]
(
    @i_initiativeId INT = NULL,
    @i_initiativeSummary VARCHAR(200) = NULL,
    @i_initiativeDescription VARCHAR(2000) = NULL,
    @i_initiativeOwner INT = NULL,
    @i_initiativeGoals VARCHAR(255) = NULL,
    @i_initiativeBusinessValue INT = NULL,
    @i_initiativeTargetStart DATE = NULL,
    @i_initiativeTargetEnd DATE = NULL,
    @i_initiativeCreationDate DATETIME = NULL,
    @i_initiativeCreatorId INT = NULL,
    @i_initiativeModificationDate DATETIME = NULL,
    @i_initiativeModificatorId INT = NULL,
    @i_initiativeStatus INT = NULL,
    @i_PageNumber INT = NULL,
    @i_RowsPerPage INT = NULL,
    @w_Accion CHAR(1),
    @o_Numero INT = NULL OUT,
    @o_MensajeTecnico VARCHAR(500) = NULL OUT,
    @o_MensajeUsuario VARCHAR(500) = NULL OUT
)
AS
BEGIN
    DECLARE @w_totalRows INT;

    IF @i_initiativeCreationDate IS NULL
        SET @i_initiativeCreationDate = GETDATE();
    IF @i_initiativeModificationDate IS NULL
        SET @i_initiativeModificationDate = GETDATE();

    -- 1. INSERTAR (I)
    IF @w_Accion = 'I'
    BEGIN
        IF ISNULL(@i_initiativeSummary, '') = ''
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL RESUMEN DE LA INICIATIVA ES OBLIGATORIO';
        END
        ELSE IF ISNULL(@i_initiativeOwner, 0) = 0
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL PROPIETARIO DE LA INICIATIVA ES OBLIGATORIO';
        END
        -- Validación de Llave Foránea: Owner en TBL_Users
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_SECURITY].[TBL_Users] (NOLOCK) WHERE userId = @i_initiativeOwner)
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL USUARIO PROPIETARIO NO EXISTE';
        END
        -- Validación de Llave Foránea: Business Value
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_CATALOGS].[TBL_BusinessValues] (NOLOCK) WHERE businessValueId = @i_initiativeBusinessValue)
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL VALOR DE NEGOCIO NO EXISTE';
        END
        -- Validación de Llave Foránea: Status
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_CATALOGS].[TBL_Status] (NOLOCK) WHERE statusId = @i_initiativeStatus)
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL ESTADO NO EXISTE';
        END
        ELSE
        BEGIN
            BEGIN TRANSACTION TRX_INS_INIT;
            BEGIN TRY
                INSERT INTO [SQM_GENERAL].[TBL_Initiatives]
                (initiativeSummary, initiativeDescription, initiativeOwner, initiativeGoals, initiativeBusinessValue, initiativeTargetStart, initiativeTargetEnd, initiativeCreationDate, initiativeCreatorId, initiativeModificationDate, initiativeModificatorId, initiativeStatus)
                VALUES
                (@i_initiativeSummary, @i_initiativeDescription, @i_initiativeOwner, @i_initiativeGoals, @i_initiativeBusinessValue, @i_initiativeTargetStart, @i_initiativeTargetEnd, @i_initiativeCreationDate, @i_initiativeCreatorId, @i_initiativeModificationDate, @i_initiativeModificatorId, @i_initiativeStatus);

                COMMIT TRANSACTION TRX_INS_INIT;
                SET @o_Numero = 201;
                SET @o_MensajeUsuario = 'INICIATIVA REGISTRADA CORRECTAMENTE';
            END TRY
            BEGIN CATCH
                ROLLBACK TRANSACTION TRX_INS_INIT;
                SET @o_Numero = 500;
                SET @o_MensajeUsuario = 'ERROR AL REGISTRAR INICIATIVA';
                SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL REGISTRAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
            END CATCH
        END
    END

    -- 2. ACTUALIZAR (U)
    ELSE IF @w_Accion = 'U'
    BEGIN
        IF ISNULL(@i_initiativeId, 0) = 0
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL ID DE LA INICIATIVA ES OBLIGATORIO';
        END
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_GENERAL].[TBL_Initiatives] (NOLOCK) WHERE initiativeId = @i_initiativeId)
        BEGIN
            SET @o_Numero = 404;
            SET @o_MensajeUsuario = 'LA INICIATIVA NO EXISTE';
        END
        ELSE
        BEGIN
            BEGIN TRANSACTION TRX_UPD_INIT;
            BEGIN TRY
                UPDATE [SQM_GENERAL].[TBL_Initiatives]
                SET initiativeSummary = COALESCE(@i_initiativeSummary, initiativeSummary),
                    initiativeDescription = COALESCE(@i_initiativeDescription, initiativeDescription),
                    initiativeOwner = COALESCE(@i_initiativeOwner, initiativeOwner),
                    initiativeGoals = COALESCE(@i_initiativeGoals, initiativeGoals),
                    initiativeBusinessValue = COALESCE(@i_initiativeBusinessValue, initiativeBusinessValue),
                    initiativeTargetStart = COALESCE(@i_initiativeTargetStart, initiativeTargetStart),
                    initiativeTargetEnd = COALESCE(@i_initiativeTargetEnd, initiativeTargetEnd),
                    initiativeModificationDate = @i_initiativeModificationDate,
                    initiativeModificatorId = @i_initiativeModificatorId,
                    initiativeStatus = COALESCE(@i_initiativeStatus, initiativeStatus)
                WHERE initiativeId = @i_initiativeId;

                COMMIT TRANSACTION TRX_UPD_INIT;
                SET @o_Numero = 200;
                SET @o_MensajeUsuario = 'INICIATIVA ACTUALIZADA CORRECTAMENTE';
            END TRY
            BEGIN CATCH
                ROLLBACK TRANSACTION TRX_UPD_INIT;
                SET @o_Numero = 500;
                SET @o_MensajeUsuario = 'ERROR AL ACTUALIZAR INICIATIVA';
                SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL ACTUALIZAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
            END CATCH
        END
    END

    -- 3. LISTAR (S)
    ELSE IF @w_Accion = 'S'
    BEGIN
        BEGIN TRY
            SET @i_PageNumber = ISNULL(@i_PageNumber, 1);
            SET @i_RowsPerPage = ISNULL(@i_RowsPerPage, 10);

            SELECT initiativeId, initiativeSummary, initiativeDescription, initiativeOwner, initiativeGoals, initiativeBusinessValue, initiativeTargetStart, initiativeTargetEnd, initiativeCreationDate, initiativeCreatorId, initiativeModificationDate, initiativeModificatorId, initiativeStatus
            FROM [SQM_GENERAL].[TBL_Initiatives] (NOLOCK)
            ORDER BY initiativeId
            OFFSET (@i_PageNumber - 1) * @i_RowsPerPage ROWS
            FETCH NEXT @i_RowsPerPage ROWS ONLY;

            SET @w_totalRows = @@ROWCOUNT;
            IF (@w_totalRows > 0)
            BEGIN
                SET @o_Numero = 200;
                SET @o_MensajeUsuario = 'INICIATIVAS LISTADAS CORRECTAMENTE';
            END
            ELSE
            BEGIN
                SET @o_Numero = 204;
                SET @o_MensajeUsuario = 'NO HAY MÁS REGISTROS PARA LISTAR';
            END
        END TRY
        BEGIN CATCH
            SET @o_Numero = 500;
            SET @o_MensajeUsuario = 'ERROR AL LISTAR INICIATIVAS';
            SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL LISTAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
        END CATCH
    END
    ELSE
    BEGIN
        SET @o_Numero = 405;
        SET @o_MensajeUsuario = 'MÉTODO NO HABILITADO';
    END
END;
GO


CREATE OR ALTER PROC [SQM_CATALOGS].[USP_Priorities]
(
    @i_priorityId INT = NULL,
    @i_priorityName VARCHAR(80) = NULL,
    @i_priorityCreationDate DATETIME = NULL,
    @i_priorityCreatorId INT = NULL,
    @i_priorityModificationDate DATETIME = NULL,
    @i_priorityModificatorId INT = NULL,
    @i_priorityEnable BIT = NULL,
    @i_PageNumber INT = NULL,
    @i_RowsPerPage INT = NULL,
    @w_Accion CHAR(1),
    @o_Numero INT = NULL OUT,
    @o_MensajeTecnico VARCHAR(500) = NULL OUT,
    @o_MensajeUsuario VARCHAR(500) = NULL OUT
)
AS
BEGIN
    DECLARE @w_totalRows INT;

    IF @i_priorityCreationDate IS NULL
        SET @i_priorityCreationDate = GETDATE();
    IF @i_priorityModificationDate IS NULL
        SET @i_priorityModificationDate = GETDATE();

    -- 1. INSERTAR (I)
    IF @w_Accion = 'I'
    BEGIN
        IF ISNULL(@i_priorityName, '') = ''
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL NOMBRE DE LA PRIORIDAD ES OBLIGATORIO';
        END
        ELSE IF ISNULL(@i_priorityCreatorId, 0) = 0
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL ID DEL CREADOR ES OBLIGATORIO';
        END
        ELSE IF EXISTS (SELECT 1 FROM [SQM_CATALOGS].[TBL_Priorities] (NOLOCK) WHERE priorityName = @i_priorityName)
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL NOMBRE DE LA PRIORIDAD YA EXISTE';
        END
        ELSE
        BEGIN
            BEGIN TRANSACTION TRX_INS_PRIO;
            BEGIN TRY
                INSERT INTO [SQM_CATALOGS].[TBL_Priorities]
                (priorityName, priorityCreationDate, priorityCreatorId, priorityModificationDate, priorityModificatorId, priorityEnable)
                VALUES
                (@i_priorityName, @i_priorityCreationDate, @i_priorityCreatorId, @i_priorityModificationDate, @i_priorityModificatorId, 1);

                COMMIT TRANSACTION TRX_INS_PRIO;
                SET @o_Numero = 201;
                SET @o_MensajeUsuario = 'PRIORIDAD REGISTRADA CORRECTAMENTE';
            END TRY
            BEGIN CATCH
                ROLLBACK TRANSACTION TRX_INS_PRIO;
                SET @o_Numero = 500;
                SET @o_MensajeUsuario = 'ERROR AL REGISTRAR LA PRIORIDAD';
                SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL REGISTRAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
            END CATCH
        END
    END

    -- 2. ACTUALIZAR (U)
    ELSE IF @w_Accion = 'U'
    BEGIN
        IF ISNULL(@i_priorityId, 0) = 0
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL ID DE LA PRIORIDAD ES OBLIGATORIO';
        END
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_CATALOGS].[TBL_Priorities] (NOLOCK) WHERE priorityId = @i_priorityId)
        BEGIN
            SET @o_Numero = 404;
            SET @o_MensajeUsuario = 'LA PRIORIDAD NO EXISTE';
        END
        ELSE IF @i_priorityName IS NOT NULL AND EXISTS (SELECT 1 FROM [SQM_CATALOGS].[TBL_Priorities] (NOLOCK) WHERE priorityName = @i_priorityName AND priorityId <> @i_priorityId)
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL NOMBRE YA EXISTE EN OTRO REGISTRO';
        END
        ELSE
        BEGIN
            BEGIN TRANSACTION TRX_UPD_PRIO;
            BEGIN TRY
                UPDATE [SQM_CATALOGS].[TBL_Priorities]
                SET priorityName = COALESCE(@i_priorityName, priorityName),
                    priorityModificationDate = @i_priorityModificationDate,
                    priorityModificatorId = @i_priorityModificatorId,
                    priorityEnable = COALESCE(@i_priorityEnable, priorityEnable)
                WHERE priorityId = @i_priorityId;

                COMMIT TRANSACTION TRX_UPD_PRIO;
                SET @o_Numero = 200;
                SET @o_MensajeUsuario = 'PRIORIDAD ACTUALIZADA CORRECTAMENTE';
            END TRY
            BEGIN CATCH
                ROLLBACK TRANSACTION TRX_UPD_PRIO;
                SET @o_Numero = 500;
                SET @o_MensajeUsuario = 'ERROR AL ACTUALIZAR LA PRIORIDAD';
                SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL ACTUALIZAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
            END CATCH
        END
    END

    -- 3. LISTAR (S)
    ELSE IF @w_Accion = 'S'
    BEGIN
        BEGIN TRY
            SET @i_PageNumber = ISNULL(@i_PageNumber, 1);
            SET @i_RowsPerPage = ISNULL(@i_RowsPerPage, 10);

            SELECT priorityId, priorityName, priorityCreationDate, priorityCreatorId, priorityModificationDate, priorityModificatorId, priorityEnable
            FROM [SQM_CATALOGS].[TBL_Priorities] (NOLOCK)
            ORDER BY priorityId
            OFFSET (@i_PageNumber - 1) * @i_RowsPerPage ROWS
            FETCH NEXT @i_RowsPerPage ROWS ONLY;

            SET @w_totalRows = @@ROWCOUNT;
            IF (@w_totalRows > 0)
            BEGIN
                SET @o_Numero = 200;
                SET @o_MensajeUsuario = 'PRIORIDADES LISTADAS CORRECTAMENTE';
            END
            ELSE
            BEGIN
                SET @o_Numero = 204;
                SET @o_MensajeUsuario = 'NO HAY MÁS REGISTROS PARA LISTAR';
            END
        END TRY
        BEGIN CATCH
            SET @o_Numero = 500;
            SET @o_MensajeUsuario = 'ERROR AL LISTAR LAS PRIORIDADES';
            SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL LISTAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
        END CATCH
    END
    ELSE
    BEGIN
        SET @o_Numero = 405;
        SET @o_MensajeUsuario = 'MÉTODO NO HABILITADO';
    END
END;
GO


CREATE OR ALTER PROC [SQM_GENERAL].[USP_Epics]
(
    @i_epicId INT = NULL,
    @i_epicName VARCHAR(100) = NULL,
    @i_epicSummary VARCHAR(500) = NULL,
    @i_epicDescription VARCHAR(4000) = NULL,
    @i_epicParentLink INT = NULL,
    @i_epicOwner INT = NULL,
    @i_epicStartDate DATE = NULL,
    @i_epicDueDate DATE = NULL,
    @i_epicPriority INT = NULL,
    @i_epicCreationDate DATETIME = NULL,
    @i_epicCreatorId INT = NULL,
    @i_epicModificationDate DATETIME = NULL,
    @i_epicModificatorId INT = NULL,
    @i_epicStatus INT = NULL,
    @i_PageNumber INT = NULL,
    @i_RowsPerPage INT = NULL,
    @w_Accion CHAR(1),
    @o_Numero INT = NULL OUT,
    @o_MensajeTecnico VARCHAR(500) = NULL OUT,
    @o_MensajeUsuario VARCHAR(500) = NULL OUT
)
AS
BEGIN
    DECLARE @w_totalRows INT;

    IF @i_epicCreationDate IS NULL
        SET @i_epicCreationDate = GETDATE();
    IF @i_epicModificationDate IS NULL
        SET @i_epicModificationDate = GETDATE();

    -- 1. INSERTAR (I)
    IF @w_Accion = 'I'
    BEGIN
        IF ISNULL(@i_epicName, '') = ''
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL NOMBRE DE LA ÉPICA ES OBLIGATORIO';
        END
        -- Validación FK: Padre Iniciativa
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_GENERAL].[TBL_Initiatives] (NOLOCK) WHERE initiativeId = @i_epicParentLink)
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'LA INICIATIVA PADRE NO EXISTE';
        END
        -- Validación FK: Propietario
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_SECURITY].[TBL_Users] (NOLOCK) WHERE userId = @i_epicOwner)
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL USUARIO PROPIETARIO NO EXISTE';
        END
        -- Validación FK: Prioridad (opcional en creación, pero validada si se envía)
        ELSE IF @i_epicPriority IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [SQM_CATALOGS].[TBL_Priorities] (NOLOCK) WHERE priorityId = @i_epicPriority)
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'LA PRIORIDAD NO EXISTE';
        END
        -- Validación FK: Estado
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_CATALOGS].[TBL_Status] (NOLOCK) WHERE statusId = @i_epicStatus)
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL ESTADO NO EXISTE';
        END
        ELSE
        BEGIN
            BEGIN TRANSACTION TRX_INS_EPIC;
            BEGIN TRY
                INSERT INTO [SQM_GENERAL].[TBL_Epics]
                (epicName, epicSummary, epicDescription, epicParentLink, epicOwner, epicStartDate, epicDueDate, epicPriority, epicCreationDate, epicCreatorId, epicModificationDate, epicModificatorId, epicStatus)
                VALUES
                (@i_epicName, @i_epicSummary, @i_epicDescription, @i_epicParentLink, @i_epicOwner, @i_epicStartDate, @i_epicDueDate, @i_epicPriority, @i_epicCreationDate, @i_epicCreatorId, @i_epicModificationDate, @i_epicModificatorId, @i_epicStatus);

                COMMIT TRANSACTION TRX_INS_EPIC;
                SET @o_Numero = 201;
                SET @o_MensajeUsuario = 'ÉPICA REGISTRADA CORRECTAMENTE';
            END TRY
            BEGIN CATCH
                ROLLBACK TRANSACTION TRX_INS_EPIC;
                SET @o_Numero = 500;
                SET @o_MensajeUsuario = 'ERROR AL REGISTRAR LA ÉPICA';
                SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL REGISTRAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
            END CATCH
        END
    END

    -- 2. ACTUALIZAR (U)
    ELSE IF @w_Accion = 'U'
    BEGIN
        IF ISNULL(@i_epicId, 0) = 0
        BEGIN
            SET @o_Numero = 400;
            SET @o_MensajeUsuario = 'EL ID DE LA ÉPICA ES OBLIGATORIO';
        END
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_GENERAL].[TBL_Epics] (NOLOCK) WHERE epicId = @i_epicId)
        BEGIN
            SET @o_Numero = 404;
            SET @o_MensajeUsuario = 'LA ÉPICA NO EXISTE';
        END
        ELSE
        BEGIN
            BEGIN TRANSACTION TRX_UPD_EPIC;
            BEGIN TRY
                UPDATE [SQM_GENERAL].[TBL_Epics]
                SET epicName = COALESCE(@i_epicName, epicName),
                    epicSummary = COALESCE(@i_epicSummary, epicSummary),
                    epicDescription = COALESCE(@i_epicDescription, epicDescription),
                    epicParentLink = COALESCE(@i_epicParentLink, epicParentLink),
                    epicOwner = COALESCE(@i_epicOwner, epicOwner),
                    epicStartDate = COALESCE(@i_epicStartDate, epicStartDate),
                    epicDueDate = COALESCE(@i_epicDueDate, epicDueDate),
                    epicPriority = COALESCE(@i_epicPriority, epicPriority),
                    epicModificationDate = @i_epicModificationDate,
                    epicModificatorId = @i_epicModificatorId,
                    epicStatus = COALESCE(@i_epicStatus, epicStatus)
                WHERE epicId = @i_epicId;

                COMMIT TRANSACTION TRX_UPD_EPIC;
                SET @o_Numero = 200;
                SET @o_MensajeUsuario = 'ÉPICA ACTUALIZADA CORRECTAMENTE';
            END TRY
            BEGIN CATCH
                ROLLBACK TRANSACTION TRX_UPD_EPIC;
                SET @o_Numero = 500;
                SET @o_MensajeUsuario = 'ERROR AL ACTUALIZAR LA ÉPICA';
                SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL ACTUALIZAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
            END CATCH
        END
    END

    -- 3. LISTAR (S)
    ELSE IF @w_Accion = 'S'
    BEGIN
        BEGIN TRY
            SET @i_PageNumber = ISNULL(@i_PageNumber, 1);
            SET @i_RowsPerPage = ISNULL(@i_RowsPerPage, 10);

            SELECT epicId, epicName, epicSummary, epicDescription, epicParentLink, epicOwner, epicStartDate, epicDueDate, epicPriority, epicCreationDate, epicCreatorId, epicModificationDate, epicModificatorId, epicStatus
            FROM [SQM_GENERAL].[TBL_Epics] (NOLOCK)
            ORDER BY epicId
            OFFSET (@i_PageNumber - 1) * @i_RowsPerPage ROWS
            FETCH NEXT @i_RowsPerPage ROWS ONLY;

            SET @w_totalRows = @@ROWCOUNT;
            IF (@w_totalRows > 0)
            BEGIN
                SET @o_Numero = 200;
                SET @o_MensajeUsuario = 'ÉPICAS LISTADAS CORRECTAMENTE';
            END
            ELSE
            BEGIN
                SET @o_Numero = 204;
                SET @o_MensajeUsuario = 'NO HAY MÁS REGISTROS PARA LISTAR';
            END
        END TRY
        BEGIN CATCH
            SET @o_Numero = 500;
            SET @o_MensajeUsuario = 'ERROR AL LISTAR LAS ÉPICAS';
            SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL LISTAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
        END CATCH
    END
    ELSE
    BEGIN
        SET @o_Numero = 405;
        SET @o_MensajeUsuario = 'MÉTODO NO HABILITADO';
    END
END;
GO


CREATE OR ALTER PROC [SQM_GENERAL].[USP_Features]
(
    @i_featureId INT = NULL,
    @i_featureSummary VARCHAR(500) = NULL,
    @i_featureDescription VARCHAR(2000) = NULL,
    @i_featuresAcceptanceCriteria VARCHAR(4000) = NULL,
    @i_featureParentLink INT = NULL,
    @i_featureOwner INT = NULL,
    @i_featureStartDate DATE = NULL,
    @i_featureDueDate DATE = NULL,
    @i_featurePriority INT = NULL,
    @i_featureCreationDate DATETIME = NULL,
    @i_featureCreatorId INT = NULL,
    @i_featureModificationDate DATETIME = NULL,
    @i_featureModificatorId INT = NULL,
    @i_featureStatus INT = NULL,
    @i_PageNumber INT = NULL,
    @i_RowsPerPage INT = NULL,
    @w_Accion CHAR(1),
    @o_Numero INT = NULL OUT,
    @o_MensajeTecnico VARCHAR(500) = NULL OUT,
    @o_MensajeUsuario VARCHAR(500) = NULL OUT
)
AS
BEGIN
    DECLARE @w_totalRows INT;

    IF @i_featureCreationDate IS NULL SET @i_featureCreationDate = GETDATE();
    IF @i_featureModificationDate IS NULL SET @i_featureModificationDate = GETDATE();

    -- 1. INSERTAR (I)
    IF @w_Accion = 'I'
    BEGIN
        IF ISNULL(@i_featureSummary, '') = ''
        BEGIN
            SET @o_Numero = 400; SET @o_MensajeUsuario = 'EL RESUMEN DEL FEATURE ES OBLIGATORIO';
        END
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_GENERAL].[TBL_Epics] (NOLOCK) WHERE epicId = @i_featureParentLink)
        BEGIN
            SET @o_Numero = 400; SET @o_MensajeUsuario = 'LA ÉPICA PADRE NO EXISTE';
        END
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_SECURITY].[TBL_Users] (NOLOCK) WHERE userId = @i_featureOwner)
        BEGIN
            SET @o_Numero = 400; SET @o_MensajeUsuario = 'EL PROPIETARIO NO EXISTE';
        END
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_CATALOGS].[TBL_Status] (NOLOCK) WHERE statusId = @i_featureStatus)
        BEGIN
            SET @o_Numero = 400; SET @o_MensajeUsuario = 'EL ESTADO NO EXISTE';
        END
        ELSE
        BEGIN
            BEGIN TRANSACTION TRX_INS_FEAT;
            BEGIN TRY
                INSERT INTO [SQM_GENERAL].[TBL_Features]
                (featureSummary, featureDescription, featuresAcceptanceCriteria, featureParentLink, featureOwner, featureStartDate, featureDueDate, featurePriority, featureCreationDate, featureCreatorId, featureModificationDate, featureModificatorId, featureStatus)
                VALUES
                (@i_featureSummary, @i_featureDescription, @i_featuresAcceptanceCriteria, @i_featureParentLink, @i_featureOwner, @i_featureStartDate, @i_featureDueDate, @i_featurePriority, @i_featureCreationDate, @i_featureCreatorId, @i_featureModificationDate, @i_featureModificatorId, @i_featureStatus);

                COMMIT TRANSACTION TRX_INS_FEAT;
                SET @o_Numero = 201; SET @o_MensajeUsuario = 'FEATURE REGISTRADO CORRECTAMENTE';
            END TRY
            BEGIN CATCH
                ROLLBACK TRANSACTION TRX_INS_FEAT;
                SET @o_Numero = 500; SET @o_MensajeUsuario = 'ERROR AL REGISTRAR EL FEATURE';
                SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL REGISTRAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
            END CATCH
        END
    END

    -- 2. ACTUALIZAR (U)
    ELSE IF @w_Accion = 'U'
    BEGIN
        IF ISNULL(@i_featureId, 0) = 0
        BEGIN
            SET @o_Numero = 400; SET @o_MensajeUsuario = 'EL ID DEL FEATURE ES OBLIGATORIO';
        END
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_GENERAL].[TBL_Features] (NOLOCK) WHERE featureId = @i_featureId)
        BEGIN
            SET @o_Numero = 404; SET @o_MensajeUsuario = 'EL FEATURE NO EXISTE';
        END
        ELSE
        BEGIN
            BEGIN TRANSACTION TRX_UPD_FEAT;
            BEGIN TRY
                UPDATE [SQM_GENERAL].[TBL_Features]
                SET featureSummary = COALESCE(@i_featureSummary, featureSummary),
                    featureDescription = COALESCE(@i_featureDescription, featureDescription),
                    featuresAcceptanceCriteria = COALESCE(@i_featuresAcceptanceCriteria, featuresAcceptanceCriteria),
                    featureParentLink = COALESCE(@i_featureParentLink, featureParentLink),
                    featureOwner = COALESCE(@i_featureOwner, featureOwner),
                    featureStartDate = COALESCE(@i_featureStartDate, featureStartDate),
                    featureDueDate = COALESCE(@i_featureDueDate, featureDueDate),
                    featurePriority = COALESCE(@i_featurePriority, featurePriority),
                    featureModificationDate = @i_featureModificationDate,
                    featureModificatorId = @i_featureModificatorId,
                    featureStatus = COALESCE(@i_featureStatus, featureStatus)
                WHERE featureId = @i_featureId;

                COMMIT TRANSACTION TRX_UPD_FEAT;
                SET @o_Numero = 200; SET @o_MensajeUsuario = 'FEATURE ACTUALIZADO CORRECTAMENTE';
            END TRY
            BEGIN CATCH
                ROLLBACK TRANSACTION TRX_UPD_FEAT;
                SET @o_Numero = 500; SET @o_MensajeUsuario = 'ERROR AL ACTUALIZAR EL FEATURE';
                SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL ACTUALIZAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
            END CATCH
        END
    END

    -- 3. LISTAR (S)
    ELSE IF @w_Accion = 'S'
    BEGIN
        BEGIN TRY
            SET @i_PageNumber = ISNULL(@i_PageNumber, 1);
            SET @i_RowsPerPage = ISNULL(@i_RowsPerPage, 10);

            SELECT featureId, featureSummary, featureDescription, featuresAcceptanceCriteria, featureParentLink, featureOwner, featureStartDate, featureDueDate, featurePriority, featureCreationDate, featureCreatorId, featureModificationDate, featureModificatorId, featureStatus
            FROM [SQM_GENERAL].[TBL_Features] (NOLOCK)
            ORDER BY featureId
            OFFSET (@i_PageNumber - 1) * @i_RowsPerPage ROWS
            FETCH NEXT @i_RowsPerPage ROWS ONLY;

            SET @w_totalRows = @@ROWCOUNT;
            IF (@w_totalRows > 0)
            BEGIN
                SET @o_Numero = 200; SET @o_MensajeUsuario = 'FEATURES LISTADOS CORRECTAMENTE';
            END
            ELSE
            BEGIN
                SET @o_Numero = 204; SET @o_MensajeUsuario = 'NO HAY MÁS REGISTROS PARA LISTAR';
            END
        END TRY
        BEGIN CATCH
            SET @o_Numero = 500; SET @o_MensajeUsuario = 'ERROR AL LISTAR FEATURES';
            SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL LISTAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
        END CATCH
    END
    ELSE
    BEGIN
        SET @o_Numero = 405; SET @o_MensajeUsuario = 'MÉTODO NO HABILITADO';
    END
END;
GO


CREATE OR ALTER PROC [SQM_GENERAL].[USP_ProductBacklogItems]
(
    @i_PBIId INT = NULL,
    @i_PBISummary VARCHAR(500) = NULL,
    @i_PBIDescription VARCHAR(2000) = NULL,
    @i_PBIsAcceptanceCriteria VARCHAR(4000) = NULL,
    @i_PBIOwner INT = NULL,
    @i_PBIParentLink INT = NULL,
    @i_PBIStoryPoint INT = NULL,
    @i_PBIStartDate DATE = NULL,
    @i_PBIDueDate DATE = NULL,
    @i_PBIPriority INT = NULL,
    @i_PBICreationDate DATETIME = NULL,
    @i_PBICreatorId INT = NULL,
    @i_PBIModificationDate DATETIME = NULL,
    @i_PBIModificatorId INT = NULL,
    @i_PBIStatus INT = NULL,
    @i_PageNumber INT = NULL,
    @i_RowsPerPage INT = NULL,
    @w_Accion CHAR(1),
    @o_Numero INT = NULL OUT,
    @o_MensajeTecnico VARCHAR(500) = NULL OUT,
    @o_MensajeUsuario VARCHAR(500) = NULL OUT
)
AS
BEGIN
    DECLARE @w_totalRows INT;

    IF @i_PBICreationDate IS NULL SET @i_PBICreationDate = GETDATE();
    IF @i_PBIModificationDate IS NULL SET @i_PBIModificationDate = GETDATE();

    -- 1. INSERTAR (I)
    IF @w_Accion = 'I'
    BEGIN
        IF ISNULL(@i_PBISummary, '') = ''
        BEGIN
            SET @o_Numero = 400; SET @o_MensajeUsuario = 'EL RESUMEN DEL PBI ES OBLIGATORIO';
        END
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_GENERAL].[TBL_Features] (NOLOCK) WHERE featureId = @i_PBIParentLink)
        BEGIN
            SET @o_Numero = 400; SET @o_MensajeUsuario = 'EL FEATURE PADRE NO EXISTE';
        END
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_SECURITY].[TBL_Users] (NOLOCK) WHERE userId = @i_PBIOwner)
        BEGIN
            SET @o_Numero = 400; SET @o_MensajeUsuario = 'EL PROPIETARIO NO EXISTE';
        END
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_CATALOGS].[TBL_Status] (NOLOCK) WHERE statusId = @i_PBIStatus)
        BEGIN
            SET @o_Numero = 400; SET @o_MensajeUsuario = 'EL ESTADO NO EXISTE';
        END
        ELSE
        BEGIN
            BEGIN TRANSACTION TRX_INS_PBI;
            BEGIN TRY
                INSERT INTO [SQM_GENERAL].[TBL_ProductBacklogItems]
                (PBISummary, PBIDescription, PBIsAcceptanceCriteria, PBIOwner, PBIParentLink, PBIStoryPoint, PBIStartDate, PBIDueDate, PBIPriority, PBICreationDate, PBICreatorId, PBIModificationDate, PBIModificatorId, PBIStatus)
                VALUES
                (@i_PBISummary, @i_PBIDescription, @i_PBIsAcceptanceCriteria, @i_PBIOwner, @i_PBIParentLink, @i_PBIStoryPoint, @i_PBIStartDate, @i_PBIDueDate, @i_PBIPriority, @i_PBICreationDate, @i_PBICreatorId, @i_PBIModificationDate, @i_PBIModificatorId, @i_PBIStatus);

                COMMIT TRANSACTION TRX_INS_PBI;
                SET @o_Numero = 201; SET @o_MensajeUsuario = 'PBI REGISTRADO CORRECTAMENTE';
            END TRY
            BEGIN CATCH
                ROLLBACK TRANSACTION TRX_INS_PBI;
                SET @o_Numero = 500; SET @o_MensajeUsuario = 'ERROR AL REGISTRAR EL PBI';
                SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL REGISTRAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
            END CATCH
        END
    END

    -- 2. ACTUALIZAR (U)
    ELSE IF @w_Accion = 'U'
    BEGIN
        IF ISNULL(@i_PBIId, 0) = 0
        BEGIN
            SET @o_Numero = 400; SET @o_MensajeUsuario = 'EL ID DEL PBI ES OBLIGATORIO';
        END
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_GENERAL].[TBL_ProductBacklogItems] (NOLOCK) WHERE PBIId = @i_PBIId)
        BEGIN
            SET @o_Numero = 404; SET @o_MensajeUsuario = 'EL PBI NO EXISTE';
        END
        ELSE
        BEGIN
            BEGIN TRANSACTION TRX_UPD_PBI;
            BEGIN TRY
                UPDATE [SQM_GENERAL].[TBL_ProductBacklogItems]
                SET PBISummary = COALESCE(@i_PBISummary, PBISummary),
                    PBIDescription = COALESCE(@i_PBIDescription, PBIDescription),
                    PBIsAcceptanceCriteria = COALESCE(@i_PBIsAcceptanceCriteria, PBIsAcceptanceCriteria),
                    PBIOwner = COALESCE(@i_PBIOwner, PBIOwner),
                    PBIParentLink = COALESCE(@i_PBIParentLink, PBIParentLink),
                    PBIStoryPoint = COALESCE(@i_PBIStoryPoint, PBIStoryPoint),
                    PBIStartDate = COALESCE(@i_PBIStartDate, PBIStartDate),
                    PBIDueDate = COALESCE(@i_PBIDueDate, PBIDueDate),
                    PBIPriority = COALESCE(@i_PBIPriority, PBIPriority),
                    PBIModificationDate = @i_PBIModificationDate,
                    PBIModificatorId = @i_PBIModificatorId,
                    PBIStatus = COALESCE(@i_PBIStatus, PBIStatus)
                WHERE PBIId = @i_PBIId;

                COMMIT TRANSACTION TRX_UPD_PBI;
                SET @o_Numero = 200; SET @o_MensajeUsuario = 'PBI ACTUALIZADO CORRECTAMENTE';
            END TRY
            BEGIN CATCH
                ROLLBACK TRANSACTION TRX_UPD_PBI;
                SET @o_Numero = 500; SET @o_MensajeUsuario = 'ERROR AL ACTUALIZAR EL PBI';
                SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL ACTUALIZAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
            END CATCH
        END
    END

    -- 3. LISTAR (S)
    ELSE IF @w_Accion = 'S'
    BEGIN
        BEGIN TRY
            SET @i_PageNumber = ISNULL(@i_PageNumber, 1);
            SET @i_RowsPerPage = ISNULL(@i_RowsPerPage, 10);

            SELECT PBIId, PBISummary, PBIDescription, PBIsAcceptanceCriteria, PBIOwner, PBIParentLink, PBIStoryPoint, PBIStartDate, PBIDueDate, PBIPriority, PBICreationDate, PBICreatorId, PBIModificationDate, PBIModificatorId, PBIStatus
            FROM [SQM_GENERAL].[TBL_ProductBacklogItems] (NOLOCK)
            ORDER BY PBIId
            OFFSET (@i_PageNumber - 1) * @i_RowsPerPage ROWS
            FETCH NEXT @i_RowsPerPage ROWS ONLY;

            SET @w_totalRows = @@ROWCOUNT;
            IF (@w_totalRows > 0)
            BEGIN
                SET @o_Numero = 200; SET @o_MensajeUsuario = 'PBIs LISTADOS CORRECTAMENTE';
            END
            ELSE
            BEGIN
                SET @o_Numero = 204; SET @o_MensajeUsuario = 'NO HAY MÁS REGISTROS PARA LISTAR';
            END
        END TRY
        BEGIN CATCH
            SET @o_Numero = 500; SET @o_MensajeUsuario = 'ERROR AL LISTAR PBIs';
            SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL LISTAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
        END CATCH
    END
    ELSE
    BEGIN
        SET @o_Numero = 405; SET @o_MensajeUsuario = 'MÉTODO NO HABILITADO';
    END
END;
GO


CREATE OR ALTER PROC [SQM_CATALOGS].[USP_ActivityTypes]
(
    @i_activityTypeId INT = NULL,
    @i_activityTypeName VARCHAR(80) = NULL,
    @i_activityTypeCreationDate DATETIME = NULL,
    @i_activityTypeCreatorId INT = NULL,
    @i_activityTypeModificationDate DATETIME = NULL,
    @i_activityTypeModificatorId INT = NULL,
    @i_activityTypeEnable BIT = NULL,
    @i_PageNumber INT = NULL,
    @i_RowsPerPage INT = NULL,
    @w_Accion CHAR(1),
    @o_Numero INT = NULL OUT,
    @o_MensajeTecnico VARCHAR(500) = NULL OUT,
    @o_MensajeUsuario VARCHAR(500) = NULL OUT
)
AS
BEGIN
    DECLARE @w_totalRows INT;

    IF @i_activityTypeCreationDate IS NULL SET @i_activityTypeCreationDate = GETDATE();
    IF @i_activityTypeModificationDate IS NULL SET @i_activityTypeModificationDate = GETDATE();

    -- 1. INSERTAR (I)
    IF @w_Accion = 'I'
    BEGIN
        IF ISNULL(@i_activityTypeName, '') = ''
        BEGIN
            SET @o_Numero = 400; SET @o_MensajeUsuario = 'EL NOMBRE DEL TIPO DE ACTIVIDAD ES OBLIGATORIO';
        END
        ELSE IF EXISTS (SELECT 1 FROM [SQM_CATALOGS].[TBL_ActivityTypes] (NOLOCK) WHERE activityTypeName = @i_activityTypeName)
        BEGIN
            SET @o_Numero = 400; SET @o_MensajeUsuario = 'EL TIPO DE ACTIVIDAD YA EXISTE';
        END
        ELSE
        BEGIN
            BEGIN TRANSACTION TRX_INS_ACT_TYPE;
            BEGIN TRY
                INSERT INTO [SQM_CATALOGS].[TBL_ActivityTypes]
                (activityTypeName, activityTypeCreationDate, activityTypeCreatorId, activityTypeModificationDate, activityTypeModificatorId, activityTypeEnable)
                VALUES
                (@i_activityTypeName, @i_activityTypeCreationDate, @i_activityTypeCreatorId, @i_activityTypeModificationDate, @i_activityTypeModificatorId, 1);

                COMMIT TRANSACTION TRX_INS_ACT_TYPE;
                SET @o_Numero = 201; SET @o_MensajeUsuario = 'TIPO DE ACTIVIDAD REGISTRADO CORRECTAMENTE';
            END TRY
            BEGIN CATCH
                ROLLBACK TRANSACTION TRX_INS_ACT_TYPE;
                SET @o_Numero = 500; SET @o_MensajeUsuario = 'ERROR AL REGISTRAR TIPO DE ACTIVIDAD';
                SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL REGISTRAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
            END CATCH
        END
    END

    -- 2. ACTUALIZAR (U)
    ELSE IF @w_Accion = 'U'
    BEGIN
        IF ISNULL(@i_activityTypeId, 0) = 0
        BEGIN
            SET @o_Numero = 400; SET @o_MensajeUsuario = 'EL ID DEL TIPO DE ACTIVIDAD ES OBLIGATORIO';
        END
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_CATALOGS].[TBL_ActivityTypes] (NOLOCK) WHERE activityTypeId = @i_activityTypeId)
        BEGIN
            SET @o_Numero = 404; SET @o_MensajeUsuario = 'EL TIPO DE ACTIVIDAD NO EXISTE';
        END
        ELSE
        BEGIN
            BEGIN TRANSACTION TRX_UPD_ACT_TYPE;
            BEGIN TRY
                UPDATE [SQM_CATALOGS].[TBL_ActivityTypes]
                SET activityTypeName = COALESCE(@i_activityTypeName, activityTypeName),
                    activityTypeModificationDate = @i_activityTypeModificationDate,
                    activityTypeModificatorId = @i_activityTypeModificatorId,
                    activityTypeEnable = COALESCE(@i_activityTypeEnable, activityTypeEnable)
                WHERE activityTypeId = @i_activityTypeId;

                COMMIT TRANSACTION TRX_UPD_ACT_TYPE;
                SET @o_Numero = 200; SET @o_MensajeUsuario = 'TIPO DE ACTIVIDAD ACTUALIZADO CORRECTAMENTE';
            END TRY
            BEGIN CATCH
                ROLLBACK TRANSACTION TRX_UPD_ACT_TYPE;
                SET @o_Numero = 500; SET @o_MensajeUsuario = 'ERROR AL ACTUALIZAR TIPO DE ACTIVIDAD';
                SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL ACTUALIZAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
            END CATCH
        END
    END

    -- 3. LISTAR (S)
    ELSE IF @w_Accion = 'S'
    BEGIN
        BEGIN TRY
            SET @i_PageNumber = ISNULL(@i_PageNumber, 1);
            SET @i_RowsPerPage = ISNULL(@i_RowsPerPage, 10);

            SELECT activityTypeId, activityTypeName, activityTypeCreationDate, activityTypeCreatorId, activityTypeModificationDate, activityTypeModificatorId, activityTypeEnable
            FROM [SQM_CATALOGS].[TBL_ActivityTypes] (NOLOCK)
            ORDER BY activityTypeId
            OFFSET (@i_PageNumber - 1) * @i_RowsPerPage ROWS
            FETCH NEXT @i_RowsPerPage ROWS ONLY;

            SET @w_totalRows = @@ROWCOUNT;
            IF (@w_totalRows > 0)
            BEGIN
                SET @o_Numero = 200; SET @o_MensajeUsuario = 'TIPOS DE ACTIVIDAD LISTADOS CORRECTAMENTE';
            END
            ELSE
            BEGIN
                SET @o_Numero = 204; SET @o_MensajeUsuario = 'NO HAY MÁS REGISTROS PARA LISTAR';
            END
        END TRY
        BEGIN CATCH
            SET @o_Numero = 500; SET @o_MensajeUsuario = 'ERROR AL LISTAR TIPOS DE ACTIVIDAD';
            SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL LISTAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
        END CATCH
    END
    ELSE
    BEGIN
        SET @o_Numero = 405; SET @o_MensajeUsuario = 'MÉTODO NO HABILITADO';
    END
END;
GO


CREATE OR ALTER PROC [SQM_GENERAL].[USP_Tasks]
(
    @i_taskId INT = NULL,
    @i_taskSummary VARCHAR(500) = NULL,
    @i_taskDescription VARCHAR(2000) = NULL,
    @i_taskOwner INT = NULL,
    @i_taskParentLink INT = NULL,
    @i_taskOriginalEstimate DECIMAL(4,2) = NULL,
    @i_taskCompletedWork DECIMAL(4,2) = NULL,
    @i_taskRemaningWork DECIMAL(4,2) = NULL,
    @i_taskStartDate DATE = NULL,
    @i_taskCompletedDate DATE = NULL,
    @i_taskDueDate DATE = NULL,
    @i_taskActivityType INT = NULL,
    @i_taskCreationDate DATETIME = NULL,
    @i_taskCreatorId INT = NULL,
    @i_taskModificationDate DATETIME = NULL,
    @i_taskModificatorId INT = NULL,
    @i_taskStatus INT = NULL,
    @i_PageNumber INT = NULL,
    @i_RowsPerPage INT = NULL,
    @w_Accion CHAR(1),
    @o_Numero INT = NULL OUT,
    @o_MensajeTecnico VARCHAR(500) = NULL OUT,
    @o_MensajeUsuario VARCHAR(500) = NULL OUT
)
AS
BEGIN
    DECLARE @w_totalRows INT;

    IF @i_taskCreationDate IS NULL SET @i_taskCreationDate = GETDATE();
    IF @i_taskModificationDate IS NULL SET @i_taskModificationDate = GETDATE();

    -- 1. INSERTAR (I)
    IF @w_Accion = 'I'
    BEGIN
        IF ISNULL(@i_taskSummary, '') = ''
        BEGIN
            SET @o_Numero = 400; SET @o_MensajeUsuario = 'EL RESUMEN DE LA TAREA ES OBLIGATORIO';
        END
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_GENERAL].[TBL_ProductBacklogItems] (NOLOCK) WHERE PBIId = @i_taskParentLink)
        BEGIN
            SET @o_Numero = 400; SET @o_MensajeUsuario = 'EL PBI PADRE NO EXISTE';
        END
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_SECURITY].[TBL_Users] (NOLOCK) WHERE userId = @i_taskOwner)
        BEGIN
            SET @o_Numero = 400; SET @o_MensajeUsuario = 'EL PROPIETARIO NO EXISTE';
        END
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_CATALOGS].[TBL_Status] (NOLOCK) WHERE statusId = @i_taskStatus)
        BEGIN
            SET @o_Numero = 400; SET @o_MensajeUsuario = 'EL ESTADO NO EXISTE';
        END
        ELSE
        BEGIN
            BEGIN TRANSACTION TRX_INS_TASK;
            BEGIN TRY
                INSERT INTO [SQM_GENERAL].[TBL_Tasks]
                (taskSummary, taskDescription, taskOwner, taskParentLink, taskOriginalEstimate, taskCompletedWork, taskRemaningWork, taskStartDate, taskCompletedDate, taskDueDate, taskActivityType, taskCreationDate, taskCreatorId, taskModificationDate, taskModificatorId, taskStatus)
                VALUES
                (@i_taskSummary, @i_taskDescription, @i_taskOwner, @i_taskParentLink, @i_taskOriginalEstimate, @i_taskCompletedWork, @i_taskRemaningWork, @i_taskStartDate, @i_taskCompletedDate, @i_taskDueDate, @i_taskActivityType, @i_taskCreationDate, @i_taskCreatorId, @i_taskModificationDate, @i_taskModificatorId, @i_taskStatus);

                COMMIT TRANSACTION TRX_INS_TASK;
                SET @o_Numero = 201; SET @o_MensajeUsuario = 'TAREA REGISTRADA CORRECTAMENTE';
            END TRY
            BEGIN CATCH
                ROLLBACK TRANSACTION TRX_INS_TASK;
                SET @o_Numero = 500; SET @o_MensajeUsuario = 'ERROR AL REGISTRAR LA TAREA';
                SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL REGISTRAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
            END CATCH
        END
    END

    -- 2. ACTUALIZAR (U)
    ELSE IF @w_Accion = 'U'
    BEGIN
        IF ISNULL(@i_taskId, 0) = 0
        BEGIN
            SET @o_Numero = 400; SET @o_MensajeUsuario = 'EL ID DE LA TAREA ES OBLIGATORIO';
        END
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_GENERAL].[TBL_Tasks] (NOLOCK) WHERE taskId = @i_taskId)
        BEGIN
            SET @o_Numero = 404; SET @o_MensajeUsuario = 'LA TAREA NO EXISTE';
        END
        ELSE
        BEGIN
            BEGIN TRANSACTION TRX_UPD_TASK;
            BEGIN TRY
                UPDATE [SQM_GENERAL].[TBL_Tasks]
                SET taskSummary = COALESCE(@i_taskSummary, taskSummary),
                    taskDescription = COALESCE(@i_taskDescription, taskDescription),
                    taskOwner = COALESCE(@i_taskOwner, taskOwner),
                    taskParentLink = COALESCE(@i_taskParentLink, taskParentLink),
                    taskOriginalEstimate = COALESCE(@i_taskOriginalEstimate, taskOriginalEstimate),
                    taskCompletedWork = COALESCE(@i_taskCompletedWork, taskCompletedWork),
                    taskRemaningWork = COALESCE(@i_taskRemaningWork, taskRemaningWork),
                    taskStartDate = COALESCE(@i_taskStartDate, taskStartDate),
                    taskCompletedDate = COALESCE(@i_taskCompletedDate, taskCompletedDate),
                    taskDueDate = COALESCE(@i_taskDueDate, taskDueDate),
                    taskActivityType = COALESCE(@i_taskActivityType, taskActivityType),
                    taskModificationDate = @i_taskModificationDate,
                    taskModificatorId = @i_taskModificatorId,
                    taskStatus = COALESCE(@i_taskStatus, taskStatus)
                WHERE taskId = @i_taskId;

                COMMIT TRANSACTION TRX_UPD_TASK;
                SET @o_Numero = 200; SET @o_MensajeUsuario = 'TAREA ACTUALIZADA CORRECTAMENTE';
            END TRY
            BEGIN CATCH
                ROLLBACK TRANSACTION TRX_UPD_TASK;
                SET @o_Numero = 500; SET @o_MensajeUsuario = 'ERROR AL ACTUALIZAR LA TAREA';
                SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL ACTUALIZAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
            END CATCH
        END
    END

    -- 3. LISTAR (S)
    ELSE IF @w_Accion = 'S'
    BEGIN
        BEGIN TRY
            SET @i_PageNumber = ISNULL(@i_PageNumber, 1);
            SET @i_RowsPerPage = ISNULL(@i_RowsPerPage, 10);

            SELECT taskId, taskSummary, taskDescription, taskOwner, taskParentLink, taskOriginalEstimate, taskCompletedWork, taskRemaningWork, taskStartDate, taskCompletedDate, taskDueDate, taskActivityType, taskCreationDate, taskCreatorId, taskModificationDate, taskModificatorId, taskStatus
            FROM [SQM_GENERAL].[TBL_Tasks] (NOLOCK)
            ORDER BY taskId
            OFFSET (@i_PageNumber - 1) * @i_RowsPerPage ROWS
            FETCH NEXT @i_RowsPerPage ROWS ONLY;

            SET @w_totalRows = @@ROWCOUNT;
            IF (@w_totalRows > 0)
            BEGIN
                SET @o_Numero = 200; SET @o_MensajeUsuario = 'TAREAS LISTADAS CORRECTAMENTE';
            END
            ELSE
            BEGIN
                SET @o_Numero = 204; SET @o_MensajeUsuario = 'NO HAY MÁS REGISTROS PARA LISTAR';
            END
        END TRY
        BEGIN CATCH
            SET @o_Numero = 500; SET @o_MensajeUsuario = 'ERROR AL LISTAR TAREAS';
            SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL LISTAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
        END CATCH
    END
    ELSE
    BEGIN
        SET @o_Numero = 405; SET @o_MensajeUsuario = 'MÉTODO NO HABILITADO';
    END
END;
GO


CREATE OR ALTER PROC [SQM_GENERAL].[USP_TaskComments]
(
    @i_taskCommentId INT = NULL,
    @i_taskCommentParentLink INT = NULL,
    @i_taskCommentOwner INT = NULL,
    @i_taskCommentText NVARCHAR(4000) = NULL,
    @i_taskCommentCreationDate DATETIME = NULL,
    @i_taskCommentCreatorId INT = NULL,
    @i_taskCommentModificationDate DATETIME = NULL,
    @i_taskCommentModificatorId INT = NULL,
    @i_taskCommentStatus BIT = NULL,
    @i_PageNumber INT = NULL,
    @i_RowsPerPage INT = NULL,
    @w_Accion CHAR(1),
    @o_Numero INT = NULL OUT,
    @o_MensajeTecnico VARCHAR(500) = NULL OUT,
    @o_MensajeUsuario VARCHAR(500) = NULL OUT
)
AS
BEGIN
    DECLARE @w_totalRows INT;

    IF @i_taskCommentCreationDate IS NULL SET @i_taskCommentCreationDate = GETDATE();
    IF @i_taskCommentModificationDate IS NULL SET @i_taskCommentModificationDate = GETDATE();

    -- 1. INSERTAR (I)
    IF @w_Accion = 'I'
    BEGIN
        IF ISNULL(@i_taskCommentText, '') = ''
        BEGIN
            SET @o_Numero = 400; SET @o_MensajeUsuario = 'EL TEXTO DEL COMENTARIO ES OBLIGATORIO';
        END
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_GENERAL].[TBL_Tasks] (NOLOCK) WHERE taskId = @i_taskCommentParentLink)
        BEGIN
            SET @o_Numero = 400; SET @o_MensajeUsuario = 'LA TAREA PADRE NO EXISTE';
        END
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_SECURITY].[TBL_Users] (NOLOCK) WHERE userId = @i_taskCommentOwner)
        BEGIN
            SET @o_Numero = 400; SET @o_MensajeUsuario = 'EL PROPIETARIO DEL COMENTARIO NO EXISTE';
        END
        ELSE
        BEGIN
            BEGIN TRANSACTION TRX_INS_COMMENT;
            BEGIN TRY
                INSERT INTO [SQM_GENERAL].[TBL_TaskComments]
                (taskCommentParentLink, taskCommentOwner, taskCommentText, taskCommentCreationDate, taskCommentCreatorId, taskCommentModificationDate, taskCommentModificatorId, taskCommentStatus)
                VALUES
                (@i_taskCommentParentLink, @i_taskCommentOwner, @i_taskCommentText, @i_taskCommentCreationDate, @i_taskCommentCreatorId, @i_taskCommentModificationDate, @i_taskCommentModificatorId, 1);

                COMMIT TRANSACTION TRX_INS_COMMENT;
                SET @o_Numero = 201; SET @o_MensajeUsuario = 'COMENTARIO REGISTRADO CORRECTAMENTE';
            END TRY
            BEGIN CATCH
                ROLLBACK TRANSACTION TRX_INS_COMMENT;
                SET @o_Numero = 500; SET @o_MensajeUsuario = 'ERROR AL REGISTRAR EL COMENTARIO';
                SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL REGISTRAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
            END CATCH
        END
    END

    -- 2. ACTUALIZAR (U)
    ELSE IF @w_Accion = 'U'
    BEGIN
        IF ISNULL(@i_taskCommentId, 0) = 0
        BEGIN
            SET @o_Numero = 400; SET @o_MensajeUsuario = 'EL ID DEL COMENTARIO ES OBLIGATORIO';
        END
        ELSE IF NOT EXISTS (SELECT 1 FROM [SQM_GENERAL].[TBL_TaskComments] (NOLOCK) WHERE taskCommentId = @i_taskCommentId)
        BEGIN
            SET @o_Numero = 404; SET @o_MensajeUsuario = 'EL COMENTARIO NO EXISTE';
        END
        ELSE
        BEGIN
            BEGIN TRANSACTION TRX_UPD_COMMENT;
            BEGIN TRY
                UPDATE [SQM_GENERAL].[TBL_TaskComments]
                SET taskCommentText = COALESCE(@i_taskCommentText, taskCommentText),
                    taskCommentModificationDate = @i_taskCommentModificationDate,
                    taskCommentModificatorId = @i_taskCommentModificatorId,
                    taskCommentStatus = COALESCE(@i_taskCommentStatus, taskCommentStatus)
                WHERE taskCommentId = @i_taskCommentId;

                COMMIT TRANSACTION TRX_UPD_COMMENT;
                SET @o_Numero = 200; SET @o_MensajeUsuario = 'COMENTARIO ACTUALIZADO CORRECTAMENTE';
            END TRY
            BEGIN CATCH
                ROLLBACK TRANSACTION TRX_UPD_COMMENT;
                SET @o_Numero = 500; SET @o_MensajeUsuario = 'ERROR AL ACTUALIZAR EL COMENTARIO';
                SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL ACTUALIZAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
            END CATCH
        END
    END

    -- 3. LISTAR (S)
    ELSE IF @w_Accion = 'S'
    BEGIN
        BEGIN TRY
            SET @i_PageNumber = ISNULL(@i_PageNumber, 1);
            SET @i_RowsPerPage = ISNULL(@i_RowsPerPage, 10);

            SELECT taskCommentId, taskCommentParentLink, taskCommentOwner, taskCommentText, taskCommentCreationDate, taskCommentCreatorId, taskCommentModificationDate, taskCommentModificatorId, taskCommentStatus
            FROM [SQM_GENERAL].[TBL_TaskComments] (NOLOCK)
            ORDER BY taskCommentId
            OFFSET (@i_PageNumber - 1) * @i_RowsPerPage ROWS
            FETCH NEXT @i_RowsPerPage ROWS ONLY;

            SET @w_totalRows = @@ROWCOUNT;
            IF (@w_totalRows > 0)
            BEGIN
                SET @o_Numero = 200; SET @o_MensajeUsuario = 'COMENTARIOS LISTADOS CORRECTAMENTE';
            END
            ELSE
            BEGIN
                SET @o_Numero = 204; SET @o_MensajeUsuario = 'NO HAY MÁS REGISTROS PARA LISTAR';
            END
        END TRY
        BEGIN CATCH
            SET @o_Numero = 500; SET @o_MensajeUsuario = 'ERROR AL LISTAR COMENTARIOS';
            SET @o_MensajeTecnico = CONCAT_WS(' - ', 'ERROR AL LISTAR', ERROR_PROCEDURE(), ERROR_LINE(), ERROR_MESSAGE());
        END CATCH
    END
    ELSE
    BEGIN
        SET @o_Numero = 405; SET @o_MensajeUsuario = 'MÉTODO NO HABILITADO';
    END
END;
GO
